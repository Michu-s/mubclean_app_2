# 1. Usar una imagen ligera de Node
FROM node:18-alpine

# 2. Crear carpeta de trabajo en el contenedor
WORKDIR /app

# 3. Copiar los archivos de dependencias primero (para aprovechar el caché)
COPY package*.json ./

# 4. Instalar dependencias
RUN npm install --production

# 5. Copiar el resto del código del backend
COPY . .

# 6. Exponer el puerto (Render usa una variable de entorno, pero esto es buena práctica)
EXPOSE 3000

# 7. Comando para iniciar tu app
CMD ["node", "index.js"] 
# (OJO: Asegúrate que tu archivo principal se llame index.js o app.js y cámbialo aquí)