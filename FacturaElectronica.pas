unit FacturaElectronica;

interface

uses FacturaTipos, ComprobanteFiscal;

type

TOnComprobanteGenerado = procedure(Sender: TObject) of Object;

///<summary>Representa una factura electronica sus metodos para generarla, leerla y validarla
/// cumpliendo la ley del Codigo Fiscal de la Federacion (CFF) Articulos 29 y 29-A.
/// (Soporta la version 2.0 de CFD)</summary>
TFacturaElectronica = class(TFEComprobanteFiscal)
{$IFDEF VERSION_DE_PRUEBA}
  public
{$ELSE}
  private
{$ENDIF}
  fCertificado: TFECertificado;
  fBloqueFolios: TFEBloqueFolios;
  fTipoComprobante: TFeTipoComprobante;

  fExpedidoEn: TFeExpedidoEn;
  fCondicionesDePago: String;
  fDescuento: Currency;
  sMotivoDescuento: String;
  sMetodoDePago: String;



  // Totales internos
  {dTotalImpuestosTrasladados : Double;
  dTotalImpuestosRetenidos : Double;
  dSubtotal: Currency;
  dTotal: Currency;
  dDescuento : Currency;  }

  // Eventos:
  fOnComprobanteGenerado: TOnComprobanteGenerado;
  // Funciones y procedimientos

  function obtenerCertificado() : TFECertificado;
published
  property FechaGeneracion;
  property FacturaGenerada;
  property Folio;
  property SubTotal;
  property Conceptos;
  property ImpuestosRetenidos;
  property ImpuestosTrasladados;
protected
  procedure setXML(Valor: WideString); override;
  function getXML() : WideString;
public
  property Receptor: TFEContribuyente read fReceptor write fReceptor;
  property Emisor: TFEContribuyente read fEmisor write fEmisor;
  property Tipo: TFeTipoComprobante read fTipoComprobante write fTipoComprobante;
  property ExpedidoEn: TFeDireccion read fExpedidoEn write fExpedidoEn;
  property CondicionesDePago: String read fCondicionesDePago write fCondicionesDePago;
  property MetodoDePago: String read sMetodoDePago write sMetodoDePago;
  // Propiedades calculadas por esta clase:
  property Total: Currency read getTotal;


  property Certificado : TFECertificado read obtenerCertificado;
  property BloqueFolios: TFEBloqueFolios read fBloqueFolios;
  property XML : WideString read getXML write setXML;

  /// <summary>Evento que es llamado inemdiatamente despu�s de que el CFD fue generado,
  /// el cual puede ser usado para registrar en su sistema contable el registro de la factura
  // el cual es un requisito del SAT (Art 29, Fraccion VI)</summary>
  property OnComprobanteGenerado : TOnComprobanteGenerado read fOnComprobanteGenerado write fOnComprobanteGenerado;
  constructor Create(cEmisor, cCliente: TFEContribuyente; bfBloqueFolios: TFEBloqueFolios;
                     cerCertificado: TFECertificado; tcTipo: TFETipoComprobante);
  destructor Destroy; override;


  //procedure Leer(sRuta: String);
  /// <summary>Genera el archivo XML de la factura electr�nica con el sello, certificado, etc</summary>
  /// <param name="Folio">Este es el numero de folio que tendr� esta factura. Si
  /// es la primer factura, deber� iniciar con el n�mero 1 (Art. 29 Fraccion III)</param>
  /// <param name="fpFormaDePago">Forma de pago de la factura (Una sola exhibici�n o parcialidades)</param>
  /// <param name="sArchivo">Nombre del archivo junto con la ruta en la que se guardar� el archivo XML</param>
  procedure GenerarYGuardar(iFolio: Integer; fpFormaDePago: TFEFormaDePago; sArchivo: String);
  //function esValida() : Boolean;
  /// <summary>Genera la factura en formato cancelado</summary>
  // function Cancelar;
end;

const
	_RFC_VENTA_PUBLICO_EN_GENERAL = 'XAXX010101000';
	_RFC_VENTA_EXTRANJEROS        = 'XEXX010101000';

implementation

uses sysutils, Classes;

constructor TFacturaElectronica.Create(cEmisor, cCliente: TFEContribuyente;
            bfBloqueFolios: TFEBloqueFolios; cerCertificado: TFECertificado; tcTipo: TFETipoComprobante);
begin
    inherited Create;
    // Llenamos las variables internas con las de los parametros
    fEmisor:=cEmisor;
    fReceptor:=cCliente;
    fBloqueFolios:=bfBloqueFolios;
    fCertificado:=cerCertificado;
    fTipoComprobante:=tcTipo;

    // TODO: Implementar CFD 3.0 y usar la version segun sea necesario...
    // Que version de CFD sera usada?
    {if (Now < EncodeDate(2011,1,1)) then
      fComprobante := TFEComprobanteFiscal.Create;
    else
      fVersion:=TFEComprobanteFiscalV3.Create; }
end;

destructor TFacturaElectronica.Destroy();
begin
   inherited Destroy;
end;

// Obtenemos el certificado de la clase padre para obtener el record
// con los datos de serie, no aprobacion, etc.
function TFacturaElectronica.obtenerCertificado() : TFECertificado;
begin
    Result:=inherited Certificado;
end;


function TFacturaElectronica.getXML() : WideString;
begin
    Result:=inherited XML;
end;

procedure TFacturaElectronica.setXML(Valor: WideString);
var
  I: Integer;
begin
    // Leemos el XML en el Comprobante
    inherited XML:=Valor;
end;

procedure TFacturaElectronica.GenerarYGuardar(iFolio: Integer; fpFormaDePago: TFEFormaDePago; sArchivo: String);
begin
     //if ValidarCamposNecesarios() = False then
     //    raise Exception.Create('No todos los campos estan llenos.');

     if (fReceptor.RFC = '') then
        Raise Exception.Create('No hay un receptor configurado');

     // Especificamos los campos del CFD en el orden especifico
     // ya que de lo contrario no cumplir� con los requisitios del SAT
     LlenarComprobante(iFolio, fpFormaDePago);

     // Generamos el archivo
     inherited GuardarEnArchivo(sArchivo);
     
     // Mandamos llamar el evento de que se genero la factura
     if Assigned(fOnComprobanteGenerado) then
        fOnComprobanteGenerado(Self);
end;


end.
