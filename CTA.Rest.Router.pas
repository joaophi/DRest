unit CTA.Rest.Router;

interface

uses
  Web.HTTPApp, CTA.Rest.Controller, System.Generics.Collections, System.Rtti, CTA.Rest.Commons, System.Types,
  System.TypInfo;

type
  TParam = record
  strict private
    FTypeKind: TTypeKind;
    FValue: TValue;
  public
    class function New(const ATypeKind: TTypeKind; const AValue: TValue): TParam; static;

    property TypeKind: TTypeKind read FTypeKind write FTypeKind;
    property Value: TValue read FValue write FValue;
  end;

  TMethod = record
  strict private
    FClazz: TControllerClazz;
    FMethods: TMethods;
    FConstructor: TRttiMethod;
    FMethod: TRttiMethod;
  public
    class function New(const AClass: TControllerClazz; const AMethods: TMethods; const AConstructor: TRttiMethod;
      const AMethod: TRttiMethod): TMethod; static;

    property Clazz: TControllerClazz read FClazz write FClazz;
    property Methods: TMethods read FMethods write FMethods;
    property Constructorr: TRttiMethod read FConstructor write FConstructor;
    property Method: TRttiMethod read FMethod write FMethod;
  end;

  IRoute = interface(IInterface)
    ['{5909C777-7B03-47D2-BE8A-31AA9D7248D7}']
    procedure AddMethod(const AClass: TControllerClazz; const AMethods: TMethods; const AConstructor: TRttiMethod;
      const AMethod: TRttiMethod);

    function AddChild(const APath: String): IRoute; overload;
    function AddChild(const AParam: TTypeKind): IRoute; overload;

    function GetRoute(const APath: string; out ARoute: IRoute; const AParams: TList<TValue>): Boolean;
    function GetMethods: TList<TMethod>;
  end;

  IRouter = interface(IInterface)
    ['{7310FCE2-C37B-4C07-AD60-D5C52A3B13F9}']
    function Execute(const ARequest: TWebRequest; const AResponse: TWebResponse): Boolean;
  end;

  TRoute = class(TInterfacedObject, IRoute)
  strict private
    FPathChilds: TDictionary<String, IRoute>;
    FParamChilds: TDictionary<TTypeKind, IRoute>;
    FMethods: TList<TMethod>;
  public
    constructor Create; overload;
    destructor Destroy; override;

    procedure AddMethod(const AClass: TControllerClazz; const AMethods: TMethods; const AConstructor: TRttiMethod;
      const AMethod: TRttiMethod);

    function AddChild(const APath: String): IRoute; overload;
    function AddChild(const AParam: TTypeKind): IRoute; overload;

    function GetRoute(const APath: string; out AEndpoint: IRoute; const AParams: TList<TValue>): Boolean;
    function GetMethods: TList<TMethod>;
  end;

  TRouter = class(TInterfacedObject, IRouter)
  strict private
    FContext: TRttiContext;
    FRoute: IRoute;

    procedure SetupController(const AController: TControllerClazz);
    procedure SetupMethod(ARoute: IRoute; const AController: TControllerClazz; const AConstructor: TRttiMethod;
      const AMethod: TRttiMethod);
  public
    constructor Create(const AControllers: array of TControllerClazz);
    function Execute(const ARequest: TWebRequest; const AResponse: TWebResponse): Boolean;
  end;

implementation

uses
  System.StrUtils, System.SysUtils;

const
  SUPPORTED_TYPES = [tkString, tkLString, tkWString, tkUString, tkInteger, tkInt64];

function GetPath(AType: TRttiType): String;
var
  lAttribute: TCustomAttribute;
begin
  Result := EmptyStr;
  repeat
    for lAttribute in AType.GetAttributes do
      if lAttribute is PathAttribute then
      begin
        Result := PathAttribute(lAttribute).Path + Result;
        Break;
      end;

    AType := AType.BaseType;
  until AType = nil;
end;

function Setup(const ARoute: IRoute; const APath: string; AMethod: TRttiMethod): IRoute;
var
  I: Integer;
  lPathSegment: string;
  lParam: TRttiParameter;
begin
  Result := ARoute;

  if not Assigned(AMethod) then
    raise Exception.Create('método compativel não encontrado');

  if AMethod.IsConstructor and (GetTypeData(AMethod.GetParameters[0].ParamType.Handle)^.ClassType <> TWebRequest) then
    raise Exception.Create('método compativel não encontrado');

  if AMethod.IsConstructor and (GetTypeData(AMethod.GetParameters[1].ParamType.Handle)^.ClassType <> TWebResponse) then
    raise Exception.Create('método compativel não encontrado');

  if AMethod.IsConstructor then
    I := 2
  else
    I := 0;
  for lPathSegment in SplitString(LowerCase(APath), '/') do
    if StartsStr(':', lPathSegment) then
    begin
      lParam := AMethod.GetParameters[I];
      Inc(I);
      if not(lParam.ParamType.TypeKind in SUPPORTED_TYPES) then
        raise Exception.Create('método possui parâmetro não suportado');
      if not SameText(':' + lParam.Name, lPathSegment) then
        raise Exception.Create('método compatível não encontrado');
      Result := Result.AddChild(lParam.ParamType.TypeKind);
    end
    else
      Result := Result.AddChild(lPathSegment);
end;

function GetTypeKinds(const ATypes: array of TTypeKind; const APath: string; out AParam: TParam): Boolean;
var
  I: Integer;
  lValue: TValue;
  lInt64: Int64;
  lInt: Integer;
begin
  Result := False;
  for I := 0 to High(ATypes) do
  begin
    case ATypes[I] of
      tkString, tkLString, tkWString, tkUString:
        lValue := APath;
      tkInt64:
        if TryStrToInt64(APath, lInt64) then
          lValue := lInt64;
      tkInteger:
        if TryStrToInt(APath, lInt) then
          lValue := lInt;
    end;
    if not lValue.IsEmpty then
    begin
      AParam := TParam.New(ATypes[I], lValue);
      Exit(True);
    end;
  end;
end;

{ TParam }

class function TParam.New(const ATypeKind: TTypeKind; const AValue: TValue): TParam;
begin
  Result.TypeKind := ATypeKind;
  Result.Value := AValue;
end;

{ TMethod }

class function TMethod.New(const AClass: TControllerClazz; const AMethods: TMethods; const AConstructor: TRttiMethod;
  const AMethod: TRttiMethod): TMethod;
begin
  Result.Clazz := AClass;
  Result.Methods := AMethods;
  Result.Constructorr := AConstructor;
  Result.Method := AMethod;
end;

{ TRoute }

constructor TRoute.Create;
begin
  inherited;
  FPathChilds := TDictionary<string, IRoute>.Create;
  FParamChilds := TDictionary<TTypeKind, IRoute>.Create;
  FMethods := TList<TMethod>.Create;
end;

destructor TRoute.Destroy;
begin
  FPathChilds.Free;
  FParamChilds.Free;
  FMethods.Free;
  inherited;
end;

procedure TRoute.AddMethod(const AClass: TControllerClazz; const AMethods: TMethods; const AConstructor: TRttiMethod;
  const AMethod: TRttiMethod);
begin
  FMethods.Add(TMethod.New(AClass, AMethods, AConstructor, AMethod));
end;

function TRoute.AddChild(const APath: String): IRoute;
begin
  if APath = EmptyStr then
    Result := Self
  else if not FPathChilds.TryGetValue(APath, Result) then
  begin
    Result := TRoute.Create;
    FPathChilds.Add(APath, Result);
  end;
end;

function TRoute.AddChild(const AParam: TTypeKind): IRoute;
begin
  if not FParamChilds.TryGetValue(AParam, Result) then
  begin
    Result := TRoute.Create;
    FParamChilds.Add(AParam, Result);
  end;
end;

function TRoute.GetRoute(const APath: string; out AEndpoint: IRoute; const AParams: TList<TValue>): Boolean;
var
  lParam: TParam;
begin
  Result := True;
  if APath = EmptyStr then
    AEndpoint := Self
  else if FPathChilds.TryGetValue(LowerCase(APath), AEndpoint) then
  else if GetTypeKinds(FParamChilds.Keys.ToArray, APath, lParam) then
  begin
    AEndpoint := FParamChilds[lParam.TypeKind];
    AParams.Add(lParam.Value);
  end
  else
    Result := False;
end;

function TRoute.GetMethods: TList<TMethod>;
begin
  Result := FMethods;
end;

{ TRouter }

procedure TRouter.SetupController(const AController: TControllerClazz);
var
  lType: TRttiType;
  lPath: string;
  lConstructor: TRttiMethod;
  lRoute: IRoute;
  lMethod: TRttiMethod;
begin
  lType := FContext.GetType(AController.ClassInfo);
  lPath := GetPath(lType);

  lConstructor := nil;
  for lMethod in lType.GetMethods do
    if lMethod.IsConstructor and (not Assigned(lConstructor) or (Length(lMethod.GetParameters) > Length(lConstructor.GetParameters))) then
      lConstructor := lMethod;

  lRoute := Setup(FRoute, lPath, lConstructor);

  for lMethod in lType.GetMethods do
    SetupMethod(lRoute, AController, lConstructor, lMethod);
end;

procedure TRouter.SetupMethod(ARoute: IRoute; const AController: TControllerClazz; const AConstructor: TRttiMethod;
  const AMethod: TRttiMethod);
var
  lPath: PathAttribute;
  lMethods: MethodsAttribute;
  lMethodsTypes: TMethods;
  lAttribute: TCustomAttribute;
begin
  if (AMethod.MethodKind <> mkProcedure) or AMethod.IsClassMethod then
    Exit;

  lPath := nil;
  lMethods := nil;
  lMethodsTypes := [mtAny];
  for lAttribute in AMethod.GetAttributes do
    if lAttribute is PathAttribute and not Assigned(lPath) then
      lPath := PathAttribute(lAttribute)
    else if lAttribute is MethodsAttribute and not Assigned(lMethods) then
      lMethods := MethodsAttribute(lAttribute);

  if not Assigned(lPath) then
    Exit;

  if Assigned(lMethods) then
    lMethodsTypes := lMethods.Methods;

  ARoute := Setup(ARoute, lPath.Path, AMethod);

  ARoute.AddMethod(AController, lMethodsTypes, AConstructor, AMethod);
end;

constructor TRouter.Create(const AControllers: array of TControllerClazz);
var
  lController: TControllerClazz;
begin
  FContext := TRttiContext.Create;
  FRoute := TRoute.Create;
  for lController in AControllers do
    SetupController(lController);
end;

function TRouter.Execute(const ARequest: TWebRequest; const AResponse: TWebResponse): Boolean;
var
  lParams: TList<TValue>;
  lRoute: IRoute;
  lPaths: TStringDynArray;
  I: Integer;
  lRouteAux: IRoute;
  lRouteParams: TArray<TValue>;
  lMethod: TMethod;
  lMethodParams: TArray<TValue>;
  lController: TController;
begin
  Result := False;

  lParams := TList<TValue>.Create;
  try
    lParams.AddRange([ARequest, AResponse]);
    lRoute := FRoute;
    lPaths := SplitString(string(ARequest.PathInfo), '/');
    for I := 0 to High(lPaths) do
    begin
      if not lRoute.GetRoute(lPaths[I], lRouteAux, lParams) then
        Exit;
      lRoute := lRouteAux;
    end;
    lRouteParams := lParams.ToArray;
  finally
    lParams.Free;
  end;

  for I := 0 to lRoute.GetMethods.Count - 1 do
  begin
    lMethod := lRoute.GetMethods[I];

    if not(mtAny in lMethod.Methods)
      and not(ARequest.MethodType in lMethod.Methods) then
      Continue;

    lMethodParams := Copy(lRouteParams, 0, Length(lMethod.Constructorr.GetParameters));
    lController := lMethod.Constructorr.Invoke(lMethod.Clazz, lMethodParams).AsType<TController>;
    try
      lController.OnBeforeAction(lMethod.Method.Name, Result);
      if not Result then
      begin
        lMethodParams := Copy(lRouteParams, Length(lMethodParams), Length(lRouteParams) - Length(lMethodParams));
        lMethod.Method.Invoke(lController, lMethodParams);

        lController.OnAfterAction(lMethod.Method.Name);
      end;
      Exit(True);
    finally
      lController.Free;
    end;
  end;
end;

end.
