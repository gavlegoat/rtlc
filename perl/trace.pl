use v5.36;
use JSON qw/decode_json/;
use Image::Magick;
use Data::Dumper;

# Utility function for rounding floats to ints.
sub round { return sprintf "%.0f", $_[0] }

###########
# Vectors #
###########

# A vector operation. The first argument is a function reference, all other
# arguments are references to arrays with the same length. The given function is
# applied to corresponding elements of each of the remaining inputs and a new
# array is constructed to hold the result.
sub vop {
    my $op = shift;
    my $u = shift;
    my @res = ();
    foreach my $i (0..$#{$u}) {
        push @res, $op->($u->[$i], map { $_->[$i] } @_);
    }
    return \@res;
}

# Vector addition
sub vadd {
    my $op = sub {
        my ($x, $y) = @_;
        return $x + $y;
    };
    return vop $op, @_
}

# Vector subtraction
sub vsub {
    my $op = sub {
        my ($x, $y) = @_;
        return $x - $y;
    };
    return vop $op, @_
}

# Vector negation
sub vneg {
    my $op = sub {
        return - $_[0]
    };
    return vop $op, @_;
}

sub vmul {
    my ($c, $v) = @_;
    my @res = map { $_ * $c } @$v;
    return \@res;
}

# Dot product
sub dot {
    my $op = sub {
        my ($x, $y) = @_;
        return $x * $y;
    };
    my $sum = 0;
    foreach (@{vop $op, @_}) {
        $sum += $_;
    }
    return $sum;
}

# Magnitude of a vector
sub magnitude {
    my $u = shift;
    return sqrt(dot $u, $u);
}

sub normalize {
    my $v = shift;
    return vmul(1 / magnitude($v), $v);
}

# Project the first argument onto the second.
sub project {
    my ($u, $v) = @_;
    my $c = dot($u, $v) / dot($v, $v);
    return vmul($c, $v);
}


###########
# Objects #
###########

# A sphere is a hash with keys "refl", "color", "center", "radius"
# A plane is a hash with keys "refl", "color", "point", "normal", "checkerboard"
#     if "checkerboard" is true then it also has "orientation" and "check_color"

# Get the color of an object at a point. This works for either type of object.
sub objcolor {
    my ($tyobj, $pt) = @_;
    my $type = $tyobj->[0];
    my $obj = $tyobj->[1];
    return $obj->{'color'} unless ($type eq 'plane' && $obj->{'checkerboard'});
    my $diff = vsub $pt, $obj->{'point'};
    my $x = project $diff, $obj->{'orientation'};
    my $y = vsub $diff, $x;
    my $ix = round(magnitude $x);
    my $iy = round(magnitude $y);
    return $obj->{'color'} if ($ix + $iy) % 2 == 0;
    return $obj->{'check_color'};
}

# Get the normal vector to an object surface at a point
sub normal {
    my ($tyobj, $pt) = @_;
    my $type = $tyobj->[0];
    my $obj = $tyobj->[1];
    return $obj->{'normal'} if $type eq 'plane';
    return vsub($pt, $obj->{'center'});
}

# Find the intersection between an object and a ray
sub plane_intersection {
    my ($obj, $start, $dir) = @_;
    my $angle = dot($obj->{'normal'}, $dir);
    return -1 if abs($angle) < 1e-6;
    my $diff = vsub($obj->{'point'}, $start);
    return dot($obj->{'normal'}, $diff) / $angle;
}

sub sphere_intersection {
    my ($obj, $start, $dir) = @_;
    my $a = dot($dir, $dir);
    my $v = vsub($start, $obj->{'center'});
    my $b = 2 * dot($dir, $v);
    my $c = dot($v, $v) - $obj->{'radius'} ** 2;
    my $discr = $b ** 2 - 4 * $a * $c;
    return -1 if $discr < 0;
    my $t1 = (-$b + sqrt($discr)) / (2 * $a);
    my $t2 = (-$b - sqrt($discr)) / (2 * $a);
    return $t2 if $t1 < 0;
    return $t1 if $t2 < 0;
    return $t1 if $t1 < $t2;
    return $t2;
}

sub intersection {
    my ($tyobj, $start, $dir) = @_;
    my $type = $tyobj->[0];
    my $obj = $tyobj->[1];
    return plane_intersection($obj, $start, $dir) if $type eq 'plane';
    return sphere_intersection($obj, $start, $dir);
}

##########
# Scenes #
##########

# A scene is a hash with keys:
# - light
# - camera
# - background
# - ambient
# - specular
# - specular_power
# - max_reflections
# - objects (a list of type-object pairs)

sub nearest_intersection {
    my ($scene, $start, $dir) = @_;
    my $mintime = -1;
    my $obj = 0;
    foreach (@{$scene->{'objects'}}) {
        my $time = intersection($_, $start, $dir);
        if ($time > 0 && ($time < $mintime || $mintime < 0)) {
            $mintime = $time;
            $obj = $_;
        }
    }
    return ($mintime, $obj);
}

sub shaded {
    my ($scene, $pt) = @_;
    my $dir = vsub($scene->{'light'}, $pt);
    my $npt = vadd($pt, vmul(1e-6, $dir));
    my ($time, $obj) = nearest_intersection($scene, $npt, $dir);
    return $time >= 0;
}

# Find the lighting along a ray in a scene.
sub raycolor {
    my ($scene, $start, $dir, $refls) = @_;
    my ($t, $obj) = nearest_intersection($scene, $start, $dir);
    return $scene->{'background'} if $t < 0;
    my $col = vadd($start, vmul($t, $dir));
    my $refl = $obj->[1]{'refl'};
    my $amb = $scene->{'ambient'} * $refl;
    my $color = objcolor($obj, $col);
    my $lighting = vmul($amb, $color);
    my $norm = normalize(normal($obj, $col));
    if (!shaded($scene, $col)) {
        my $lightdir = normalize(vsub($scene->{'light'}, $col));
        my $factor = (1 - $amb) * (1 - $refl) * dot($norm, $lightdir);
        $lighting = vadd($lighting, vmul($factor, $color)) if $factor > 0;
        my $half = normalize(vadd($lightdir, normalize(vneg($dir))));
        $factor = dot($half, $norm);
        if ($factor > 0) {
            $factor = $factor ** $scene->{'specular_power'} * $scene->{'specular'};
            $lighting = vadd($lighting, vmul($factor, [255, 255, 255]));
        }
    }
    if ($refls < $scene->{'max_reflections'} && $refl > 0.003) {
        my $op = normalize(vneg($dir));
        my $ref = vadd($norm, vsub(project($op, $norm), $op));
        my $pt = vadd($col, vmul(1e-6, $ref));
        $lighting = vadd($lighting, vmul((1 - $amb) * $refl,
                raycolor($scene, $pt, $ref, $refls + 1)));
    }
    return $lighting;
}

# Find the color from the camera looking through a point.
sub pointcolor {
    my ($scene, $pt) = @_;
    return raycolor($scene, $pt, vsub($pt, $scene->{'camera'}), 0);
}

# Find the color of a pixel on the screen.
sub pixelcolor {
    my ($scene, $px, $py, $scale, $antialias) = @_;
    my $color = [0, 0, 0];
    for (1..$antialias) {
        my $x = ($px + rand) / $scale;
        my $y = 1 - ($py + rand) / $scale;
        my @pt = ($x, 0, $y);
        $color = vadd($color, pointcolor($scene, \@pt));
    }
    return vmul(1 / $antialias, $color);
}

sub add_object {
    my ($scene, $json) = @_;
    my %obj = (
        'refl' => $json->{'reflectivity'},
        'color' => $json->{'color'},
    );
    my $type = $json->{'type'};
    if ($type eq 'sphere') {
        $obj{'center'} = $json->{'center'};
        $obj{'radius'} = $json->{'radius'};
    } else {
        $obj{'point'} = $json->{'point'};
        $obj{'normal'} = $json->{'normal'};
        $obj{'checkerboard'} = $json->{'checkerboard'};
        if ($json->{'checkerboard'}) {
            $obj{'check_color'} = $json->{'color2'};
            $obj{'orientation'} = $json->{'orientation'};
        }
    }
    push(@{$scene->{'objects'}}, [$type, \%obj]);
}

sub convert {
    my $op = sub {
        my $x = shift;
        $x /= 256;
        $x >= 0 || ($x = 0);
        $x <= 1 || ($x = 1);
        return $x;
    };
    return vop($op, @_);
}

die 'Usage: perl trace.pl <config-file> <output-file>' unless $#ARGV == 1;

open(my $json_file, "<", $ARGV[0]) || die "Can't open config file";
my $json_input = join ' ', <$json_file>;
my $json = decode_json $json_input;
my $scene = {
    'light' => $json->{'light'},
    'camera' => $json->{'camera'},
    'background' => [135, 206, 235],
    'ambient' => 0.2,
    'specular' => 0.5,
    'specular_power' => 8,
    'max_reflections' => 6,
    'objects' => []
};
foreach (@{$json->{'objects'}}) {
    add_object($scene, $_)
}
my $antialias = $json->{'antialias'};

my ($width, $height) = (512, 512);

my $image = Image::Magick->new(
    size => "${width}x${height}",
    type => 'TrueColor',
    depth => 8
);
$image->Read('canvas:white');
for (my $i = 0; $i < $height; $i++) {
    my @row = ();
    for (my $j = 0; $j < $width; $j++) {
        $image->SetPixel(
            x => $j,
            y => $i,
            color => convert(pixelcolor($scene, $j, $i, $width, $antialias))
        );
    }
}
my $res = $image->Write(filename => $ARGV[1]);
warn $res if $res;
