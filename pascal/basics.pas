unit basics;

interface

uses math;

type
    Point     = record
        X : Real;
        Y : Real;
        Z : Real;
    end; 
    Vector    = record
        X : Real;
        Y : Real;
        Z : Real;
    end; 
    Ray       = record
        Start     : Point;
        Direction : Vector;
    end;
    ColorType = record       
        Red       : Real;
        Green     : Real;
        Blue      : Real;
    end;         

function DotProduct(V1, V2 : Vector) : Real;
function Project(V1, V2 : Vector) : Vector;
function Magnitude(V : Vector) : Real;
function Negate(V :  Vector) : Vector;
operator - (P1, P2 : Point) V : Vector;
operator - (V1, V2 : Vector) V : Vector;
operator * (A : Real; V : Vector) W : Vector;
operator * (A : Real; C : ColorType) C2 : ColorType;
operator + (P : Point; V : Vector) W : Point;
operator + (V1, V2 : Vector) V : Vector;
operator + (C1, C2 : ColorType) C : ColorType;

implementation

function DotProduct(V1, V2 : Vector) : Real;
begin
    DotProduct := V1.X * V2.X + V1.Y * V2.Y + V1.Z * V2.Z;
end;

function Project(V1, V2 : Vector) : Vector;
begin
    Project := DotProduct(V1, V2) / DotProduct(V2, V2) * V2;
end;

function Magnitude(V : Vector) : Real;
begin
    Magnitude := Sqrt(DotProduct(V, V));
end;

function Negate(V : Vector) : Vector;
begin
    with Negate do
    begin
    X := -V.X;
    Y := -V.Y;
    Z := -V.Z;
end;
end;

operator - (P1, P2 : Point) V : Vector;
begin
    V.X := P1.X - P2.X;
    V.Y := P1.Y - P2.Y;
    V.Z := P1.Z - P2.Z;
end;

operator - (V1, V2 : Vector) V : Vector;
begin
    V.X := V1.X - V2.X;
    V.Y := V1.Y - V2.Y;
    V.Z := V1.Z - V2.Z;
end;

operator * (A : Real; V : Vector) W : Vector;
begin
    W.X := A * V.X;
    W.Y := A * V.Y;
    W.Z := A * V.Z;
end;

operator * (A : Real; C : ColorType) C2 : ColorType;
begin
    C2.Red := A * C.Red;
    C2.Green := A * C.Green;
    C2.Blue := A * C.Blue;
end;

operator + (P : Point; V : Vector) W : Point;
begin
    W.X := P.X + V.X;
    W.Y := P.Y + V.Y;
    W.Z := P.Z + V.Z;
end;

operator + (V1, V2 : Vector) V : Vector;
begin
    V.X := V1.X + V2.X;
    V.Y := V1.Y + V2.Y;
    V.Z := V1.Z + V2.Z;
end;

operator + (C1, C2 : ColorType) C : ColorType;
begin
    C.Red := C1.Red + C2.Red;
    C.Green := C1.Green + C2.Green;
    C.Blue := C1.Blue + C2.Blue;
end;

end.
