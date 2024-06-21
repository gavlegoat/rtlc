unit shapes;

interface

uses basics, math;

type
    ShapeType    = (SphereType, PlaneType);
    Shape        = record
        Reflectivity: Real;
        Color     : ColorType;
        case SType: ShapeType of
        SphereType: (
        Center    : Point;
        Radius    : Real);
        PlaneType  : (
        Point        : Point;
        Normal       : Vector;
        Checkerboard : Boolean;
        Orientation  : Vector;
        Color2       : ColorType)
    end;
    Intersection = record
        Time : Real;
        Obj  : Shape;
    end;

function GetIntersection(R : Ray; Sh : Shape) : Real;
function GetNormal(Sh : Shape; P : Point) : Vector;
function GetColor(Sh : Shape; P : Point) : ColorType;

implementation

function GetIntersection(R : Ray; Sh : Shape) : Real;
var
    T, T2, P, A, B, C, Discr : Real;
begin
    if Sh.SType = SphereType then
    begin
    A := DotProduct(R.Direction, R.Direction);
    B := 2 * DotProduct(R.Start - Sh.Center, R.Direction);
    C := DotProduct(Sh.Center - R.Start, Sh.Center - R.Start) -
    Sh.Radius * Sh.Radius;
    Discr := B * B - 4 * A * C;
    if Discr < 0 then
    GetIntersection := -1
else
    begin
    T := (-B + Sqrt(Discr)) / (2 * A);
    T2 := (-B - Sqrt(Discr)) / (2 * A);
    if T < 0 then
    if T2 < 0 then
    GetIntersection := -1
else
    GetIntersection := T2
else
    if T2 < 0 then
    GetIntersection := T
else
    GetIntersection := min(T, T2);
end;
end
else
    begin
    P := DotProduct(Sh.Normal, R.Direction);
    if Abs(P) < 1e-6 then
    GetIntersection := -1
else
    GetIntersection := DotProduct(Sh.Point - R.Start, Sh.Normal) / P;
end;
end;

function GetNormal(Sh : Shape; P : Point) : Vector;
begin
    if Sh.SType = SphereType then
    GetNormal := P - Sh.Center
else
    GetNormal := Sh.Normal;
end;

function GetColor(Sh : Shape; P : Point) : ColorType;
var
    I, J : Integer;
    X, Y : Vector;
begin
    if (Sh.SType = SphereType) or not Sh.Checkerboard then
    GetColor := Sh.Color
else
    begin
    X := Project(P - Sh.Point, Sh.Orientation);
    Y := P - Sh.Point - X;
    I := Round(Magnitude(X));
    J := Round(Magnitude(Y));
    if ((I + J) mod 2) = 0 then
    GetColor := Sh.Color
else
    GetColor := Sh.Color2;
end;
end;

end.
