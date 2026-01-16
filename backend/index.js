require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { MercadoPagoConfig, Preference } = require('mercadopago');        

const app = express();
const port = 3000;

  // --- Middlewares ---
app.use(cors()); // Permite peticiones de otros orígenes (tu app Flutter)
app.use(express.json()); // Permite al servidor entender JSON

app.use(cors({
  origin: ['https://mubclean-web2.vercel.app/', 'http://localhost:4200'], // Tu URL de Vercel y local para pruebas
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

  // --- Configuración Mercado Pago ---
const client = new MercadoPagoConfig({
accessToken: process.env.MERCADOPAGO_ACCESS_TOKEN,
});
const preference = new Preference(client);

  // --- Rutas ---
app.get('/', (req, res) => {
    res.send('El backend de Mercado Pago está funcionando!');
});

  // Endpoint para crear la preferencia de pago
app.post('/create_preference', async (req, res) => {
    try {
        const body = {
        items: [
          {
            title: 'Mi producto',
            quantity: 1,
            unit_price: 2000,
            currency_id: 'MXN', // Mantén tu moneda local
          },
        ],
        back_urls: {
          success: 'tuapp://success',
          failure: 'tuapp://failure',
          pending: 'tuapp://pending',
        },
           auto_return: 'approved',
         };
 
         const result = await preference.create({ body });
 
         console.log('Preferencia creada:', result.id);
         res.json({ preferenceId: result.id, init_point: result.init_point });
       } catch (error) {
         console.error('Error al crear la preferencia:', error);
         res.status(500).json({ error: 'No se pudo crear la preferencia de pago' });
}
});
 
app.listen(port, () => {
console.log(`Servidor corriendo en http://localhost:${port}`);
});