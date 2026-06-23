process.env.GOOGLE_APPLICATION_CREDENTIALS =
  'C:\\Users\\sergio\\Downloads\\vercy-motos-firebase-adminsdk-fbsvc-385ca8918e.json';

const tools = require('C:\\Users\\sergio\\AppData\\Roaming\\npm\\node_modules\\firebase-tools');

tools.deploy({
  project: 'vercy-motos',
  only: 'hosting',
  cwd: __dirname,
  token: undefined,
}).then(() => {
  console.log('Deploy completado exitosamente!');
  process.exit(0);
}).catch(err => {
  console.error('Error al hacer deploy:', err.message);
  process.exit(1);
});
