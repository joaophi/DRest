unit CTA.Rest.Commons;

interface

uses
  System.SysUtils, Web.HTTPApp;

type
  TMethods = set of TMethodType;

  HTTP_STATUS = record
  const
    Continue = 100;
    SwitchingProtocols = 101;
    OK = 200;
    Created = 201;
    Accepted = 202;
    NonAuthoritativeInformation = 203;
    NoContent = 204;
    ResetContent = 205;
    PartialContent = 206;
    MultipleChoices = 300;
    MovedPermanently = 301;
    Found = 302;
    SeeOther = 303;
    NotModified = 304;
    UseProxy = 305;
    TemporaryRedirect = 307;
    BadRequest = 400;
    Unauthorized = 401;
    PaymentRequired = 402;
    Forbidden = 403;
    NotFound = 404;
    MethodNotAllowed = 405;
    NotAcceptable = 406;
    ProxyAuthenticationRequired = 407;
    RequestTimeout = 408;
    Conflict = 409;
    Gone = 410;
    LengthRequired = 411;
    PreconditionFailed = 412;
    RequestEntityTooLarge = 413;
    RequestURITooLong = 414;
    UnsupportedMediaType = 415;
    RequestedRangeNotSatisfiable = 416;
    ExpectationFailed = 417;
    UnprocessableEntity = 422;
    Locked = 423;
    FailedDependency = 424;
    InternalServerError = 500;
    NotImplemented = 501;
    BadGateway = 502;
    ServiceUnavailable = 503;
    GatewayTimeout = 504;
    HTTPVersionNotSupported = 505;
    InsufficientStorage = 507;
  end;

  EHttpException = class(Exception)
  private
    FStatusCode: Integer;
  public
    constructor Create(const Msg: string; const StatusCode: Integer = HTTP_STATUS.InternalServerError); reintroduce;
    constructor CreateFmt(const Msg: string; const Args: array of const; const StatusCode: Integer = HTTP_STATUS.InternalServerError); reintroduce;

    property StatusCode: Integer read FStatusCode write FStatusCode;
  end;

  PathAttribute = class(TCustomAttribute)
  private
    FPath: String;
  public
    constructor Create(const APath: String = '/');
    property Path: String read FPath;
  end;

  MethodsAttribute = class(TCustomAttribute)
  private
    FMethods: TMethods;
  public
    constructor Create(const AMethods: TMethods);
    property Methods: TMethods read FMethods;
  end;

implementation

uses
  System.StrUtils;

{ EHttpException }

constructor EHttpException.Create(const Msg: string; const StatusCode: Integer);
begin
  inherited Create(Msg);
  FStatusCode := StatusCode;
end;

constructor EHttpException.CreateFmt(const Msg: string; const Args: array of const; const StatusCode: Integer);
begin
  inherited CreateFmt(Msg, Args);
  FStatusCode := StatusCode;
end;

{ PathAttribute }

constructor PathAttribute.Create(const APath: String);
begin
  FPath := LowerCase(Trim(APath));
end;

{ MethodsAttribute }

constructor MethodsAttribute.Create(const AMethods: TMethods);
begin
  FMethods := AMethods;
end;

end.
