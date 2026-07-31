// Textos legales de la Plataforma. Los datos de identificación del
// responsable (razón social, NIT, dirección, contacto) se tomaron de la
// papelería fiscal real del negocio (facturas/tiquetes emitidos). Revisar
// con un abogado antes de considerarlos definitivos: este archivo es un
// punto de partida razonable, no asesoría legal.

const String _nombreResponsable = 'VERCY MOTOS';
const String _nitResponsable = '1002576776-7';
const String _direccionResponsable = 'Carrera 24B #41-42, Caldas, Manizales';
const String _correoContacto = 'vercymotos@gmail.com';
const String _telefonoContacto = '304 454 7430';
const String _ultimaActualizacion = '24 de julio de 2026';

const String terminosYCondicionesTexto = '''
TÉRMINOS Y CONDICIONES DE USO

Última actualización: $_ultimaActualizacion

1. Objeto
Estos Términos y Condiciones regulan el acceso y uso de Vercy Motos (en adelante, "la Plataforma"), un sistema ERP para la gestión administrativa, de inventario y facturación de establecimientos dedicados a la venta y/o servicio técnico de motocicletas. Al crear una cuenta, el usuario declara haber leído y aceptado estos términos.

2. Responsabilidades del usuario
- Suministrar información veraz, completa y actualizada al registrarse.
- Mantener la confidencialidad de sus credenciales de acceso (usuario y contraseña) y notificar de inmediato cualquier uso no autorizado de su cuenta.
- Utilizar la Plataforma únicamente para fines lícitos y relacionados con la operación del negocio autorizado.
- No intentar vulnerar la seguridad de la Plataforma ni acceder a información de otros usuarios o establecimientos sin autorización.

3. Responsabilidades del proveedor
- Proveer la Plataforma con las funcionalidades descritas, realizando esfuerzos razonables para mantener su disponibilidad y correcto funcionamiento.
- Implementar medidas de seguridad razonables para proteger la información almacenada.
- Notificar oportunamente cambios relevantes en el servicio o en estos Términos.

4. Disponibilidad del servicio
La Plataforma se ofrece "tal cual" y "según disponibilidad". Pueden existir interrupciones programadas (mantenimiento) o no programadas (fallas técnicas, causas de fuerza mayor). El proveedor hará esfuerzos razonables para minimizar dichas interrupciones, pero no garantiza disponibilidad ininterrumpida.

5. Limitación de responsabilidad
El proveedor no será responsable por daños indirectos, pérdida de datos, lucro cesante o perjuicios derivados del uso inadecuado de la Plataforma, de la pérdida de credenciales por negligencia del usuario, o de causas ajenas a su control razonable. El usuario es responsable de la exactitud de la información financiera y contable que registre.

6. Suspensión o cancelación de cuentas
El proveedor podrá suspender o cancelar una cuenta cuando detecte uso indebido, incumplimiento de estos Términos, o a solicitud del administrador del establecimiento asociado a la cuenta. El usuario puede solicitar la cancelación de su cuenta en cualquier momento escribiendo a $_correoContacto.

7. Propiedad intelectual
El software, su código, diseño, marca y demás elementos de la Plataforma son propiedad de Vercy Motos o de sus licenciantes. El uso de la Plataforma no otorga al usuario ningún derecho de propiedad intelectual sobre el software, más allá de la licencia de uso necesaria para operar la cuenta.

8. Modificaciones
Estos Términos pueden actualizarse. Los cambios sustanciales serán informados a los usuarios registrados.
''';

const String politicaTratamientoDatosTexto = '''
POLÍTICA DE TRATAMIENTO DE DATOS PERSONALES

Última actualización: $_ultimaActualizacion

En cumplimiento de la Ley 1581 de 2012 y el Decreto 1377 de 2013 de la República de Colombia, $_nombreResponsable informa lo siguiente respecto al tratamiento de sus datos personales.

1. Responsable del tratamiento
$_nombreResponsable, NIT $_nitResponsable, con domicilio en $_direccionResponsable, es el responsable del tratamiento de los datos personales recolectados a través de la Plataforma.

2. Datos que recopilamos
- Datos de identificación y contacto del usuario: nombre y correo electrónico, suministrados al momento del registro.
- Información asociada al uso de la Plataforma: historial de sesiones, acciones administrativas y registros de auditoría necesarios para la operación del sistema.
- Datos de clientes y transacciones que el usuario, en ejercicio de su rol, registre en la Plataforma (facturación, inventario, cotizaciones), de los cuales el establecimiento es responsable frente a sus propios clientes.

3. Finalidad del tratamiento
Los datos del usuario se usan para:
- Crear y administrar su cuenta de acceso a la Plataforma.
- Autenticar su identidad y gestionar los permisos correspondientes a su rol.
- Contactarlo respecto a la autorización de su cuenta, soporte técnico o novedades operativas del servicio.
- Cumplir obligaciones legales y contables aplicables a la operación del establecimiento.

No se envían comunicaciones comerciales ni promocionales por correo electrónico a los usuarios registrados.

4. Cómo protegemos sus datos
Implementamos medidas técnicas y administrativas razonables (cifrado de contraseñas, control de acceso basado en roles, registros de auditoría) para proteger la información contra pérdida, uso indebido, acceso no autorizado o alteración.

5. Con quién compartimos su información
Los datos no se venden ni se comparten con terceros para fines comerciales. Solo se comparten cuando es estrictamente necesario para prestar el servicio (por ejemplo, proveedores de infraestructura tecnológica) o cuando lo exija una autoridad competente.

6. Tiempo de conservación
Los datos se conservan mientras la cuenta permanezca activa y durante el tiempo adicional que exijan las normas contables, tributarias o legales aplicables. Al cancelar una cuenta, los datos podrán conservarse el tiempo legalmente requerido antes de su eliminación definitiva.

7. Derechos del titular
Como titular de sus datos personales, usted tiene derecho a:
- Conocer, actualizar y rectificar sus datos.
- Solicitar prueba de la autorización otorgada.
- Ser informado sobre el uso que se ha dado a sus datos.
- Presentar quejas ante la Superintendencia de Industria y Comercio por infracciones a la ley.
- Revocar la autorización y/o solicitar la supresión de sus datos, cuando no exista un deber legal o contractual que impida su eliminación.

Para ejercer estos derechos, puede escribir a $_correoContacto o comunicarse al $_telefonoContacto, indicando su nombre, el derecho que desea ejercer y adjuntando los documentos que soporten su solicitud.

8. Autorización
Al marcar la casilla de aceptación correspondiente, usted autoriza a $_nombreResponsable a tratar sus datos personales conforme a esta Política, de manera libre, previa, expresa e informada.
''';

const String avisoPrivacidadTexto = '''
AVISO DE PRIVACIDAD

Última actualización: $_ultimaActualizacion

$_nombreResponsable, NIT $_nitResponsable, con domicilio en $_direccionResponsable, es responsable del tratamiento de los datos personales que usted nos suministra como usuario de la Plataforma o como cliente de nuestro establecimiento.

Sus datos (identificación, contacto y, en el caso de clientes, información de facturación) se usan para gestionar su cuenta, prestar el servicio, cumplir obligaciones contables/tributarias (incluida la facturación electrónica ante la DIAN) y atender sus solicitudes. No se venden ni se ceden a terceros con fines comerciales.

Usted puede conocer, actualizar, rectificar o solicitar la supresión de sus datos, así como revocar la autorización otorgada, escribiendo a $_correoContacto o llamando al $_telefonoContacto. El tratamiento completo de sus datos se rige por nuestra Política de Tratamiento de Datos Personales, disponible en esta misma sección.
''';
