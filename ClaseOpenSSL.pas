(******************************************************************************
 PROYECTO FACTURACION ELECTRONICA
 Copyright (C) 2010 - Bambu Code SA de CV - Ing. Luis Carrasco

 Libreria usada para interactuar con la libreria OpenSSL y exportar sus metodos
 de hashing/digestion usando una llave privada.

 Este archivo pertenece al proyecto de codigo abierto de Bambu Code:
 http://bambucode.com/codigoabierto

 La licencia de este codigo fuente se encuentra en:
 http://github.com/bambucode/tfacturaelectronica/blob/master/LICENCIA
 ******************************************************************************)
 unit ClaseOpenSSL;

interface

uses libeay32, SysUtils, Windows, OpenSSLUtils, libeay32plus;

  type

    {$IF Compilerversion >= 20}
    TCadenaUTF8 = RawByteString;
    {$ELSE}
    TCadenaUTF8 = UTF8String;
    {$IFEND}

    TTipoDigestionOpenSSL = (tdMD5, tdSHA1);
    ENoExisteArchivoException = class(Exception);
    ECertificadoLlaveEsFiel = class(Exception);
    ELlaveFormatoIncorrectoException = class(Exception);
    ELlaveLecturaException = class(Exception);
    ELlavePrivadaClaveIncorrectaException = class(Exception);
    ELlavePareceSerFiel = class(Exception);

    ///<summary>Clase que representa a la liberia OpenSSL y que tiene
    ///  metodos usados para generar el sello digital (digestion md5) y
    ///  lectura de la llave privada en su formato nativo binario (.key)
    ///</summary>
    TOpenSSL = class
        fArchivoLlavePrivada: String;
        fClaveLlavePrivada: String;
    private
        function ObtenerLlavePrivadaDesencriptada() : pEVP_PKEY;
        ///<summary>Funcion usada para convertir un buffer de bytes
        /// en caracteres 'imprimibles' (codificacion base64).
        ///</summary>
        function BinToBase64(const PDat: PBYTE; const DatLen: DWORD): String;
        function ObtenerUltimoMensajeDeError: string;
    public
        /// <summary>Crea el objeto, inicializa la liberia OpenSSL, y establece la llave privada a usar</summary>
        constructor Create(); overload;
        /// <summary>Prueba abrir la llave privada, si tiene exito regresa informacion de la llave, si falla
        ///  lanza una excepcion segun el tipo de error que se tuvo</summary>
        /// <param name="Ruta">Ruta completa al archivo de llave privada a usar
        /// (archivo con extension .key)</param>
        /// <param name="ClaveLlavePrivada">La clave privada a usar para abrir el archivo de llave privada</param>
        function AbrirLlavePrivada(Ruta, ClaveLlavePrivada : String) : pPKCS8_Priv_Key_Info;
        /// <summary>Hace una digestion (hashing) de la Cadena segun el Tipo de digestion y regresa el
        /// resultado en formato base64</summary>
        /// <param name="ArchivoLlavePrivada">Ruta completa al archivo de llave privada a usar
        /// (archivo con extension .key)</param>
        /// <param name="ClaveLlavePrivada">La clave privada a usar para abrir el archivo de llave privada</param>
        /// <param name="sCadena">Cadena a la cual se va a hacer la digestion (pre-codificada en UTF8)</param>
        /// <param name="trTipo">Tipo de digestion a realizar (tdMD5, tdSHA1)</param>
        function HacerDigestion(ArchivoLlavePrivada, ClaveLlavePrivada: String; sCadena: TCadenaUTF8;
                 trTipo: TTipoDigestionOpenSSL) : String;
        /// <summary>Obtiene un certificado con sus propiedades llenas</summary>
        /// <param name="sArchivo">Ruta completa del archivo de certificado (extension .cer)</param>
        function ObtenerCertificado(sArchivo: String) : TX509Certificate;
        destructor Destroy; override;
    end;

implementation

uses  StrUtils;

constructor TOpenSSL.Create();
begin
  OpenSSL_add_all_algorithms;
  OpenSSL_add_all_ciphers;
  OpenSSL_add_all_digests;
  ERR_load_crypto_strings;
end;

destructor TOpenSSL.Destroy;
begin
  	EVP_cleanup;
    inherited;
end;

// Funcion obtenida de: DelphiAccess - http://www.delphiaccess.com/forum/index.php?topic=3092.0
// Usuario: axesys
function TOpenSSL.BinToBase64(const PDat: PBYTE; const DatLen: DWORD): string;
const BaseTable: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var s, s1: string;
	i, p, len, n, Addnum: DWORD;
	PBin: PBYTE;
begin
	result := '';
	S := '';
	addnum := 0;
	PBin := PDat;
	for i := 1 to DatLen do
	begin
		S := S + IntToHex(PBin^, 2);
		PBin := PBYTE(DWORD(PDat) + i);
	end;
	case (length(s) mod 3) of
		0: addnum := 0;
		1: begin
				s := s + '00';
				addnum := 2;
			end;
		2: begin
				s := s + '0';
				addnum := 1;
			end;
	end;
	len := length(s) div 3;
	for i := 1 to len do
	begin
		s1 := midstr(S, i * 3 - 2, 3);
		p := strtoint('$' + s1);
		n := p div 64;
		result := result + basetable[n + 1];
		n := p mod 64;
		result := result + basetable[n + 1];
	end;
	if addnum = 1 then result := result + '==';
	if addnum = 2 then result[length(result)] := '=';
end;

// Regresa el ultimo mensaje de error reportado por la liberia de OpenSSL
// Funcion copiada de OpenSSLUtils.pas de Marco Ferrante
function TOpenSSL.ObtenerUltimoMensajeDeError: string;
var
  {$IF CompilerVersion >= 20}
     ErrMsg: array [0..160] of AnsiChar;
  {$ELSE}
      ErrMsg: array [0..160] of Char;
  {$IFEND}
begin
  ERR_error_string(ERR_get_error, @ErrMsg);
  result := StrPas(PAnsiChar(@ErrMsg));
end;


function TOpenSSL.AbrirLlavePrivada(Ruta, ClaveLlavePrivada : String) : pPKCS8_Priv_Key_Info;
var
    bioArchivoLlave : pBIO;
    sMsgErr: String;
    p8 : pX509_SIG;
    p8inf : pPKCS8_Priv_Key_Info;
    {$IF CompilerVersion >= 20}
        p8pass: PAnsiChar;
    {$ELSE}
        p8pass: PChar;
    {$IFEND}
begin
    // Creamos el objeto en memoria para leer la llave en formato binario .DER (.KEY)
    bioArchivoLlave := BIO_new(BIO_s_file());

    if Not FileExists(Ruta) then
      Raise ENoExisteArchivoException.Create('El archivo de llave privada no existe.');

    // Checamos que la extension de la llave privada sea la correcta
    if AnsiPos('.PEM', Uppercase(Ruta)) > 0 then
      Raise ELlaveFormatoIncorrectoException.Create('La llave privada debe de ser el archivo binario (.key, .cer) y ' +
            'no el formato base64 .pem');

    // Leemos el archivo de llave binario en el objeto creado en memoria
    // DIferentes parametros si usa Delphi 2009 o superior...
    {$IF CompilerVersion >= 20}
        if BIO_read_filename(bioArchivoLlave, PWideChar(AnsiString(Ruta))) = 0 then
    {$ELSE}
        if BIO_read_filename(bioArchivoLlave, PChar(AnsiString(Ruta))) = 0 then
    {$IFEND}
          raise ELlaveLecturaException.Create('Error al leer llave privada. Error reportado: '+
                ObtenerUltimoMensajeDeError);

    // Checamos que la clave no est� vacia
    if Trim(ClaveLlavePrivada) = '' then
      raise ELlavePrivadaClaveIncorrectaException.Create('La clave de la llave privada esta vacia');

    // Convertimos al tipo adecuado de acuerdo a la version de Delphi...
    {$IF CompilerVersion >= 20}
        // Delphi 2009 o superior
        p8pass:=PAnsiChar(AnsiString(ClaveLlavePrivada));
    {$ELSE}
        p8pass:=PChar(AnsiString(ClaveLlavePrivada));
    {$IFEND}

    p8:=nil;
    p8inf:=nil;

    try
        //  Leemos la llave en formato binario (PKCS8)
        p8 := d2i_PKCS8_bio(bioArchivoLlave, nil);
        if not Assigned(p8) then
          raise ELlaveLecturaException.Create('Error al leer llave privada. Error reportado: '+
                ObtenerUltimoMensajeDeError);

        // Des encriptamos la llave en memoria usando la clave proporcionada
        p8inf := PKCS8_decrypt(p8, p8pass, StrLen(p8pass));
        if Not Assigned(p8inf) then
        begin
           sMsgErr:=ObtenerUltimoMensajeDeError;
           // TODO: Crear excepciones para los diferentes tipos de error que puede haber al
           // tratar de desencriptar la llave privada
           // Llave incorrecta (Mensaje exacto: 23077074:PKCS12 routines:PKCS12_pbe_crype:pkcs12 cipherfinal error)
           if ((AnsiPos('cipherfinal error', sMsgErr) > 0) or // clave incorrecta
              (AnsiPos('bad decrypt', sMsgErr) > 0))   // clave incorrecta
           then
              raise ELlavePrivadaClaveIncorrectaException.Create('La clave de la llave privada fue incorrecta')
           else
              if (AnsiPos('unknown pbe algorithm', sMsgErr) > 0) then // Clave vacia o pertenece a la FIEL
                Raise ELlavePareceSerFiel.Create('Al parecer la llave privada pertenece a la FIEL')
              else
                raise ELlaveLecturaException.Create('Error desconocido al desencriptar llave privada. Error reportado: '+
                      ObtenerUltimoMensajeDeError);

           // Nos estan dando un certificado de la FIEL??
           {if AnsiPos('bad decrypt', sMsgErr) > 0 then
              raise TCertificadoLlaveEsFiel.Create('El certificado (archivo de llave) pertenece a la FIEL. + '
              'Use el certificado de Llave Privada')
           else}
        end else

    finally
        // Liberamos las variables usadas en memoria
        X509_SIG_free(p8);
	      BIO_free(bioArchivoLlave);
        EVP_cleanup;
    end;

    Result:=p8inf;
end;

// Metodo creado por Luis Carrasco (luis@bambucode.com) con ayuda de
// Marco Ferrante <marco@csita.unige.it>
// Lee una llave binaria (.key) que tiene formato DER en memoria
// para ser usada para hacer una digestion MD5, SHA1, etc. sin necesidad
// de crear y usar un archivo PEM primero
function TOpenSSL.ObtenerLlavePrivadaDesencriptada() : pEVP_PKEY;
var
    p8inf : pPKCS8_Priv_Key_Info;
    resLlave   : pEVP_PKEY;
begin
    // Abrimos la llave privada
    p8inf:=AbrirLlavePrivada(fArchivoLlavePrivada, fClaveLlavePrivada);

    // Convierte la llave de formato PKCS8 a PEM (en memoria)
    resLlave := EVP_PKCS82PKEY(p8inf);

    // Se tuvo exito al desencriptar la llave???
    Result:=resLlave;

    // NOTA: Es responsabilidad de el metodo que llama a esta funcion de ejecutar el
    // siguiente codigo EVP_PKEY_free(pkey); una vez usado el resultado de la misma
end;

function TOpenSSL.ObtenerCertificado(sArchivo: String) : TX509Certificate;
var
  CertX509: TX509Certificate;
begin
  CertX509:=TX509Certificate.Create;
  try
      CertX509.LoadFromFile(sArchivo, DER);
  except
      On E:Exception do
      begin
         // TODO: CHecar los posibles errores generados
         // "Unable to read certificate file"
      end;
  end;

  Result:=CertX509;
end;


function TOpenSSL.HacerDigestion(ArchivoLlavePrivada, ClaveLlavePrivada: String; sCadena: TCadenaUTF8;
         trTipo: TTipoDigestionOpenSSL) : String;
var
  mdctx: EVP_MD_CTX;
  {$IF CompilerVersion >= 20}
      Inbuf: Array[0..99999] of AnsiChar; // Antes [0..8192]
      Outbuf: array [0..1024] of AnsiChar;
  {$ELSE}
      Inbuf: Array[0..99999] of Char;
      Outbuf: array [0..1024] of Char;
  {$IFEND}
	ekLlavePrivada: pEVP_PKEY;
  Len, Tam: cardinal;
begin
  fArchivoLlavePrivada:=ArchivoLlavePrivada;
  fClaveLlavePrivada:= ClaveLlavePrivada;

  Len:=0;
  ekLlavePrivada := ObtenerLlavePrivadaDesencriptada;

  //SetLength(Inbuf, 8192); // StrLen(@sCadena)

  // NOTA IMPORTANTE:
  // Esta funcion debe de recibir RawByteString en Delphi 2009 o superior y tipo UTF8String en Delphi 2007
  // de lo contrario no copiara correctamente los datos en memoria regresando sellos invalidos
  //CodeSite.Send('CodePage',StringCodePage(sCadena));
  Tam:=Length(sCadena); // Obtenemos el tama�o de la cadena original
  StrPLCopy(inbuf, sCadena, Tam);  // Copiamos la cadena original al buffer de entrada 

  if not Assigned(ekLlavePrivada) then
    Raise ELlaveLecturaException.Create('No fue posible leer la llave privada');

  // Establecemos el tipo de digestion a realizar
  case trTipo of
    tdMD5: EVP_SignInit(@mdctx,EVP_md5());
    tdSHA1: EVP_SignInit(@mdctx,EVP_sha1());
  end;

  // Establece los datos que vamos a usar
	EVP_SignUpdate(@mdctx,@inbuf,StrLen(inbuf));
  // Realiza la digestion usando la llave privada que obtuvimos y leimos en memoria
	EVP_SignFinal(@mdctx,@outbuf,Len,ekLlavePrivada);
  // Liberamos el puntero a la llave privada usada previamente
  EVP_PKEY_free(ekLlavePrivada);

  // Regresa los resultados en formato Base64
	Result := BinToBase64(@outbuf,Len);
end;

end.