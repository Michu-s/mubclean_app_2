require('dotenv').config();
const express = require('express');
const cors =require('cors');
const { MercadoPagoConfig, Preference } = require('mercadopago');
const jwt = require('jsonwebtoken'); // Importar jsonwebtoken

const app = express();
const port = 3000;

// --- Middlewares ---
app.use(cors({
  origin: ['https://mubcleanweb2.vercel.app/', 'http://localhost:4200'], // Tu URL de Vercel y local
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json());

// --- Middleware de Verificación de Token ---
const verifyToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  if (!authHeader) {
    return res.status(403).send('Se requiere un token para la autenticación');
  }

  const token = authHeader.split(' ')[1]; // Formato "Bearer TOKEN"
  if (!token) {
    return res.status(403).send('Token malformado');
  }

  try {
    // ¡IMPORTANTE! Debes configurar SUPABASE_JWT_SECRET en tu entorno (ej. Render)
    const decoded = jwt.verify(token, process.env.SUPABASE_JWT_SECRET);
    req.user = decoded; // Opcional: adjuntar datos del usuario al request
  } catch (err) {
    return res.status(401).send('Token inválido');
  }
  return next();
};


// --- Configuración Mercado Pago ---
const client = new MercadoPagoConfig({
  accessToken: process.env.MERCADOPAGO_ACCESS_TOKEN,
});
const preference = new Preference(client);

// --- Rutas ---
app.get('/', (req, res) => {
  res.send('El backend de Mercado Pago está funcionando!');
});

// Endpoint para crear la preferencia de pago (ahora protegido)
app.post('/create_preference', verifyToken, async (req, res) => {
  try {
    // Usar los datos del body del request
    const { title, quantity, unit_price } = req.body;

    if (!title || !quantity || !unit_price) {
      return res.status(400).json({ error: 'Faltan datos del producto (title, quantity, unit_price)' });
    }

    const body = {
      items: [
        {
          title: title,
          quantity: Number(quantity),
          unit_price: Number(unit_price),
          currency_id: 'MXN',
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