-module(erlang_ray).

-mode(compile).

-export([main/1, color_pixel/4, color_point/3]).

-define(WorkerLimit, 100).

main(Args) ->
    case Args of
        [InFile, OutFile] ->
            main(InFile, OutFile);
        _ ->
            io:format("Usage: ./erlang_ray <config-file> <output-file>~n")
    end,
    erlang:halt(0).

-record(object, {reflectivity, color, shape_label, shape}).
-record(sphere, {center, radius}).
-record(plane, {point, normal, checkerboard,
                color2=[0, 0, 0], orientation=[0, 0, 0]}).
-record(scene, {camera, light, ambient=0.2, specular=0.5, specular_power=8,
                max_reflections=6, background=[135, 206, 235],
                pixel_width=512, pixel_height=512, antialias, objects}).

main(InputFile, OutputFile) ->
    Scene = parse_scene(InputFile),
    Image = render(Scene),
    write_image(Image, Scene#scene.pixel_width, Scene#scene.pixel_height,
                OutputFile).

parse_scene(InputFile) ->
    case file:read_file(InputFile) of
        {error, Reason} ->
            io:format("~p~n", Reason);
        {ok, Binary} ->
            convert_from_json(jsone:decode(Binary))
    end.

convert_from_json(Data) ->
    Objects = lists:map(fun (D) -> convert_json_object(D) end,
                        maps:get(<<"objects">>, Data)),
    #scene{
       camera=maps:get(<<"camera">>, Data),
       light=maps:get(<<"light">>, Data),
       antialias=maps:get(<<"antialias">>, Data),
       objects=Objects
      }.

convert_json_object(Data) ->
    #object{
       reflectivity=maps:get( <<"reflectivity">>, Data),
       color=maps:get(<<"color">>, Data),
       shape_label=case maps:get(<<"type">>, Data) of
                       <<"sphere">> -> sphere;
                       <<"plane">> -> plane;
                       _ -> error ("Unknown object type")
                   end,
       shape=case maps:get(<<"type">>, Data) of
                 <<"sphere">> ->
                     #sphere{
                        center=maps:get(<<"center">>, Data),
                        radius=maps:get(<<"radius">>, Data)
                       };
                 <<"plane">> ->
                     case maps:get(<<"checkerboard">>, Data) of
                         true ->
                             #plane{
                                point=maps:get(<<"point">>, Data),
                                normal=maps:get(<<"normal">>, Data),
                                checkerboard=true,
                                color2=maps:get(<<"color2">>, Data),
                                orientation=maps:get(<<"orientation">>, Data)
                               };
                         false ->
                             #plane{
                                point=maps:get(<<"point">>, Data),
                                normal=maps:get(<<"normal">>, Data),
                                checkerboard=false
                               }
                     end
                 end
      }.

write_image(Image, Width, Height, OutputFile) ->
    {ok, File} = file:open(OutputFile, [write]),
    Png = png:create(#{size => {Width, Height},
                       mode => {rgb, 8},
                       file => File}),
    png:append(Png, {rows, convert_image(Image, Width, Height)}),
    png:close(Png),
    file:close(File).

convert_image(Image, Width, Height) ->
    Row = fun (Y) ->
                  lists:map(fun (X) ->
                                    clip_color(array:get(Y * Width + X, Image))
                            end, lists:seq(0, Width - 1))
          end,
    lists:map(Row, lists:seq(0, Height - 1)).

clip_color([R, G, B]) ->
    Rn = max(0, min(255, trunc(R))),
    Gn = max(0, min(255, trunc(G))),
    Bn = max(0, min(255, trunc(B))),
    <<Rn, Gn, Bn>>.

render(Scene) ->
    Data = array:new(Scene#scene.pixel_width * Scene#scene.pixel_height),
    render(Scene, 0, 0, 0, Data).

render(Scene, ActiveWorkers, I, J, Data) ->
    Done = (J == Scene#scene.pixel_height) and (I == Scene#scene.pixel_width - 1),
    if
        (ActiveWorkers == 0) and Done ->
            Data;
        (ActiveWorkers == ?WorkerLimit) or Done ->
            receive
                {ok, Ir, Jr, Color} ->
                    render(Scene, ActiveWorkers - 1, I, J,
                           array:set(Scene#scene.pixel_width * Jr + Ir,
                                     Color, Data));
                {'DOWN', _, _, _, Reason} when Reason /= normal ->
                    error({"Child process died", Reason})
            end;
        J == Scene#scene.pixel_height ->
            io:format("~p~n", [I]),
            render(Scene, ActiveWorkers, I + 1, 0, Data);
        true ->
            spawn_pixel_worker(Scene, I, J),
            render(Scene, ActiveWorkers + 1, I, J + 1, Data)
    end.

spawn_pixel_worker(Scene, I, J) ->
    spawn_monitor(?MODULE, color_pixel, [Scene, I, J, self()]).

color_pixel(Scene, I, J, Pid) ->
    Xs = lists:map(fun (_) -> I + rand:uniform() end,
                   lists:seq(1, Scene#scene.antialias)),
    Ys = lists:map(fun (_) -> J + rand:uniform() end,
                   lists:seq(1, Scene#scene.antialias)),
    Ps = lists:zip(lists:map(fun (X) -> X / Scene#scene.pixel_width end, Xs),
                   lists:map(fun (Y) -> 1 - Y / Scene#scene.pixel_width end, Ys)),
    Pids = lists:map(fun (P) ->
                             spawn_monitor(?MODULE, color_point,
                                           [Scene, P, self()])
                     end, Ps),
    color_pixel_receive(Scene#scene.antialias, length(Pids), [0, 0, 0],
                        I, J, Pid).

color_pixel_receive(A, 0, C, I, J, Pid) ->
    Result = lists:map(fun (X) -> X / A end, C),
    Pid ! {ok, I, J, Result};
color_pixel_receive(A, N, C, I, J, Pid) ->
    receive
        {ok, V} ->
            color_pixel_receive(A, N - 1,
                                lists:zipwith(fun (X, Y) -> X + Y end, V, C),
                                I, J, Pid);
        {'DOWN', _, _, _, Reason} when Reason /= normal->
            error({"Child process died", Reason})
    end.

color_point(Scene, {X, Z}, Pid) ->
    Result = color_ray(Scene, [X, 0, Z], v_minus([X, 0, Z], Scene#scene.camera), 0),
    Pid ! {ok, Result}.

color_ray(Scene, Start, Dir, Refls) ->
    case intersection(Scene, Start, Dir) of
        none ->
            Scene#scene.background;
        {T, Obj} ->
            Col = v_plus(v_times(T, Dir), Start),
            Reflect = Obj#object.reflectivity,
            Amb = Scene#scene.ambient * (1 - Reflect),
            LAmb = v_times(Amb, get_color(Obj, Col)),
            Norm = normalize(get_normal(Obj, Col)),
            Offset = v_plus(Col, v_times(1.0e-6, Norm)),
            LRefl = if
                        (Refls < Scene#scene.max_reflections) and
                        (Reflect > 0.003) ->
                            Op = normalize(v_neg(Dir)),
                            Ref = v_plus(Op, v_times(2, v_minus(project(Op, Norm), Op))),
                            v_times((1 - Amb) * Reflect,
                                    color_ray(Scene, Offset, Ref, Refls + 1));
                        true -> [0, 0, 0]
                    end,
            Shaded = in_shadow(Scene, Offset),
            if
                Shaded ->
                    v_plus(LAmb, LRefl);
                true ->
                    LDir = normalize(v_minus(Scene#scene.light, Col)),
                    LDiff = v_times((1 - Amb) * (1 - Reflect),
                                    v_times(max(0, v_dot(Norm, LDir)),
                                            get_color(Obj, Col))),
                    Half = normalize(v_plus(LDir, normalize(v_neg(Dir)))),
                    LSpec = v_times(Scene#scene.specular,
                                    v_times(math:pow(max(0, v_dot(Half, Norm)),
                                                     Scene#scene.specular_power),
                                            [255, 255, 255])),
                    v_plus(v_plus(LAmb, LRefl), v_plus(LDiff, LSpec))
            end
    end.

intersection(Scene, Start, Dir) ->
    MinIntersection =
        fun (Obj, Acc) ->
                case collision(Obj, Start, Dir) of
                    none ->
                        Acc;
                    T when Acc == none ->
                        {T, Obj};
                    T when T < element(1, Acc) ->
                        {T, Obj};
                    _ ->
                        Acc
                end
        end,
    lists:foldl(MinIntersection, none, Scene#scene.objects).

collision(Obj, Start, Dir) ->
    case Obj#object.shape_label of
        sphere ->
            Sphere = Obj#object.shape,
            C = Sphere#sphere.center,
            R = Sphere#sphere.radius,
            V = v_minus(Start, C),
            A = v_dot(Dir, Dir),
            B = 2 * v_dot(Dir, V),
            Discr = B * B - 4 * A * (v_dot(V, V) - R * R),
            if
                Discr < 0 -> none;
                true ->
                    T1 = (-B + math:sqrt(Discr)) / (2 * A),
                    T2 = (-B - math:sqrt(Discr)) / (2 * A),
                    if
                        (T1 < 0) and (T2 < 0) -> none;
                        T1 < 0 -> T2;
                        T2 < 0 -> T1;
                        true -> min(T1, T2)
                    end
            end;
        plane ->
            Plane = Obj#object.shape,
            P = Plane#plane.point,
            N = Plane#plane.normal,
            Diff = v_minus(P, Dir),
            if
                Diff < 1.0e-6 -> none;
                true ->
                    T = v_dot(N, v_minus(P, Start)) / v_dot(N, Dir),
                    if
                        T < 0 -> none;
                        true -> T
                    end
            end
    end.

in_shadow(Scene, Point) ->
    case intersection(Scene, Point, v_minus(Scene#scene.light, Point)) of
        none -> false;
        _ -> true
    end.

get_normal(Obj, Point) ->
    case Obj#object.shape_label of
        plane -> Obj#object.shape#plane.normal;
        sphere -> v_minus(Point, Obj#object.shape#sphere.center)
    end.

get_color(Obj, Point) ->
    case Obj#object.shape_label of
        plane when Obj#object.shape#plane.checkerboard ->
            P = Obj#object.shape#plane.point,
            O = Obj#object.shape#plane.orientation,
            V = v_minus(Point, P),
            X = project(V, O),
            Y = v_minus(V, X),
            E = (round(magnitude(X)) + round(magnitude(Y))) rem 2 == 0,
            if
                E -> Obj#object.color;
                true -> Obj#object.shape#plane.color2
            end;
        _ ->
            Obj#object.color
    end.

v_minus(V1, V2) ->
    lists:zipwith(fun (A, B) -> A - B end, V1, V2).

v_dot(V1, V2) ->
    lists:foldl(fun ({A1, A2}, B) -> A1 * A2 + B end,
                0,
                lists:zip(V1, V2)).

v_times(X, V) ->
    lists:map(fun (Y) -> X * Y end, V).

v_plus(V1, V2) ->
    lists:zipwith(fun (A, B) -> A + B end, V1, V2).

v_neg(V) ->
    lists:map(fun (X) -> -X end, V).

project(A, B) ->
    v_times(v_dot(A, B) / v_dot(B, B), B).

magnitude(V) -> math:sqrt(v_dot(V, V)).

normalize(V) -> v_times(1 / magnitude(V), V).
