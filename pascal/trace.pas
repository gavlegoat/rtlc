program trace;

uses
    fpjson, jsonparser, sysutils, math, classes, basics, shapes;

var
    Objects        : Array [0..99] of Shape;
    ObjectsLength  : Integer;
    ImageWidth     : Integer;
    ImageHeight    : Integer;
    MaxReflections : Integer;
    Background     : ColorType;
    Camera         : Point;
    Light          : Point;
    Ambient        : Real;
    Specular       : Real;
    SpecularPower  : Integer;
    Antialias      : Integer;
    X, Y           : Integer;
    Pixels         : Array of Array of ColorType;

function GetNearestIntersection(R : Ray) : Intersection;
var
    Near : Intersection;
    I    : Integer;
    T    : Real;
begin
    Near.Time := -1;
    for I := 0 to ObjectsLength - 1 do
    begin
    T := GetIntersection(R, Objects[I]);
    if (T > 0) and ((T < Near.Time) or (Near.Time < 0)) then
    begin
    Near.Time := T;
    Near.Obj := Objects[I];
end;
end;
    getNearestIntersection := near;
end;

function ColorRay(R : Ray; Refls : Integer) : ColorType;
var
    Int          : Intersection;
    Collision    : Point;
    Amb          : Real;
    Reflectivity : Real;
    LightDir     : Vector;
    Norm         : Vector;
    NextR        : Ray;
    V, H         : Vector;
    Reflected    : Vector;
    White        : ColorType;
begin
    Int := GetNearestIntersection(R);
    If Int.Time < 0 then
    begin
    ColorRay := Background;
    Exit;
end;
    Collision := R.Start + Int.Time * R.Direction;
    Reflectivity := Int.Obj.Reflectivity;
    Amb := Ambient * (1 - Reflectivity);
    ColorRay := Amb * GetColor(Int.Obj, Collision);
    LightDir := Light - Collision;
    LightDir := 1 / Magnitude(LightDir) * LightDir;
    V := Negate(1 / Magnitude(R.Direction) * R.Direction);
    Norm := GetNormal(Int.Obj, Collision);
    Norm := 1 / Magnitude(Norm) * Norm;
    NextR.Start := Collision + 1e-6 * LightDir;
    NextR.Direction := LightDir;
    if GetNearestIntersection(NextR).Time < 0 then
    begin
    ColorRay := ColorRay + (1 - Amb) * (1 - Reflectivity) *
    Max(0, DotProduct(Norm, LightDir)) * GetColor(Int.Obj, Collision);
    H := V + LightDir;
    H := 1 / Magnitude(H) * H;
    with White do
    begin
    Red := 255;
    Green := 255;
    Blue := 255;
end;
    ColorRay := ColorRay + Specular *
    Power(Max(0, DotProduct(H, Norm)), SpecularPower) * White;
end;
    if (Refls < MaxReflections) and (Reflectivity > 0.003) then
    begin
    Reflected := V + 2 * (Project(V, Norm) - V);
    NextR.Start := Collision + 1e-6 * Reflected;
    NextR.Direction := Reflected;
    ColorRay := ColorRay + (1 - Amb) * Reflectivity * ColorRay(NextR, Refls + 1);
end;
end;

function ColorPoint(P : Point) : ColorType;
var
    R : Ray;
begin
    with R do
    begin
    Start := Camera;
    Direction := P - Camera;
end;
    ColorPoint := ColorRay(R, 0);
end;

function ColorPixel(X, Y : Integer) : ColorType;
var
    XVal, ZVal, R : Real;
    I             : Integer;
    P             : Point;
begin
    with ColorPixel do
    begin
    Red := 0;
    Green := 0;
    Blue := 0;
end;
    for I := 1 to Antialias do
    begin
    R := Random;
    XVal := X / ImageWidth + R / ImageWidth;
    R := Random;
    ZVal := 1 - Y / ImageWidth + R / ImageWidth;
    with P do
    begin
    X := XVal;
    Y := 0;
    Z := ZVal;
end;
    ColorPixel := ColorPixel + ColorPoint(P);
end;
    with ColorPixel do
    begin
    Red := Red / Antialias;
    Green := Green / Antialias;
    Blue := Blue / Antialias;
end;
end;

function ParseObject(Json :  TJSONData) : Shape;
var
    Obj : Shape;
begin
    Obj.Reflectivity := Json.FindPath('reflectivity').AsFloat;
    with Obj.Color do
    begin
    Red := Json.FindPath('color[0]').AsFloat;
    Green := Json.FindPath('color[1]').AsFloat;
    Blue := Json.FindPath('color[2]').AsFloat;
end;
    if CompareStr(Json.FindPath('type').AsJSON, '"sphere"') = 0 then
    begin
    Obj.SType := SphereType;
    with Obj.Center do
    begin
    X := Json.FindPath('center[0]').AsFloat;
    Y := Json.FindPath('center[1]').AsFloat;
    Z := Json.FindPath('center[2]').AsFloat;
end;
    Obj.Radius := Json.FindPath('radius').AsFloat;
end
else
    begin
    Obj.SType := PlaneType;
    with Obj.Point do
    begin
    X := Json.FindPath('point[0]').AsFloat;
    Y := Json.FindPath('point[1]').AsFloat;
    Z := Json.FindPath('point[2]').AsFloat;
end;
    with Obj.Normal do
    begin
    X := Json.FindPath('normal[0]').AsFloat;
    Y := Json.FindPath('normal[1]').AsFloat;
    Z := Json.FindPath('normal[2]').AsFloat;
end;
    Obj.Checkerboard := Json.FindPath('checkerboard').AsBoolean;
    if Obj.Checkerboard then
    begin
    with Obj.Color2 do
    begin
    Red := Json.FindPath('color2[0]').AsFloat;
    Green := Json.FindPath('color2[1]').AsFloat;
    Blue := Json.FindPath('color2[2]').AsFloat;
end;
    with Obj.Orientation do
    begin
    X := Json.FindPath('orientation[0]').AsFloat;
    Y := Json.FindPath('orientation[1]').AsFloat;
    Z := Json.FindPath('orientation[2]').AsFloat;
end;
end;
end;
    ParseObject := Obj;
end;

procedure readJSON;
var
    Line        : ANSIString;
    FileIn      : Text;
    JsonString  : ANSIString;
    JsonData    : TJSONData;
    JsonObjects : TJSONData;
    I           : Integer;

begin
    Assign(FileIn, ParamStr(1));
    Reset(FileIn);
    JsonString := '';
    while not EOF(FileIn) do
    begin
    ReadLn(FileIn, Line);
    JsonString := JsonString + Line;
end;
    Close(FileIn);
    JsonData := GetJSON(JsonString);
    with Light do
    begin
    X := JsonData.FindPath('light[0]').AsFloat;
    Y := JsonData.FindPath('light[1]').AsFloat;
    Z := JsonData.FindPath('light[2]').AsFloat;
end;
    with camera do
    begin
    X := JsonData.FindPath('camera[0]').AsFloat;
    Y := JsonData.FindPath('camera[1]').AsFloat;
    Z := JsonData.FindPath('camera[2]').AsFloat;
end;
    Antialias := JsonData.FindPath('antialias').AsInteger;
    JsonObjects := JsonData.FindPath('objects');
    for I := 0 to JsonObjects.Count - 1 do
    Objects[I] := ParseObject(JsonObjects.Items[I]);
    ObjectsLength := JsonObjects.Count;
    JsonData.Free;
end;

procedure WriteImage;
var
    Out    : TFileStream;
    I, J   : Integer;
    S      : String;
    Buffer : Array[0..2] of Char;

begin
    Out := TFileStream.Create(ParamStr(2), FMCreate);
    Buffer[0] := 'P';
    Buffer[1] := '6';
    Buffer[2] := #10;
    Out.Write(Buffer, 3);

    S := IntToStr(ImageWidth);
    Out.Write(s[1], Length(S));
    Buffer[0] := ' ';
    Out.Write(Buffer, 1);
    S := IntToStr(ImageHeight);
    Out.Write(S[1], Length(S));
    Buffer[0] := #10;
    Out.write(Buffer, 1);
    S := '255';
    Out.Write(S[1], Length(S));
    Out.Write(Buffer, 1);

    for J := 0 to ImageHeight - 1 do
    for I := 0 to ImageWidth - 1 do
    begin
    Buffer[0] := Chr(Min(255, Max(0, Round(Pixels[j][i].Red))));
    Buffer[1] := Chr(Min(255, Max(0, Round(Pixels[j][i].Green))));
    Buffer[2] := Chr(Min(255, Max(0, Round(Pixels[j][i].Blue))));
    Out.Write(Buffer, 3);
end;

end;

begin
Randomize;
if ParamCount <> 2 then
begin
WriteLn('Usage: ./trace <scene-description> <output-file>');
Exit;
   end;
ReadJSON;
ImageWidth := 512;
ImageHeight := 512;
MaxReflections := 6;
with Background do
begin
Red := 135;
Green := 206;
Blue := 235;
   end;
Ambient := 0.2;
Specular := 0.5;
SpecularPower := 8;

SetLength(Pixels, ImageHeight, ImageWidth);

for X := 0 to ImageWidth - 1 do
for Y := 0 to ImageHeight - 1 do
Pixels[Y][X] := ColorPixel(X, Y);

WriteImage;
end.
