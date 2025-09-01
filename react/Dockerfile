#Build Stage
FROM node:alpine AS build
#Set up working directory 
WORKDIR /usr/src/app

#Copy only package*.json for better dependency caching
COPY package*.json ./
RUN npm install

#Copy all the container contents
COPY . .

#Build for prod and served by Nginx
RUN npm run build

#Nginx stage
FROM nginx:alpine

#Copy build react files into nginx html dir
COPY --from=build /usr/src/app/dist /usr/share/nginx/html

#Copy default.conf into nginx (production default)
COPY ./nginx/default.conf /etc/nginx/conf.d/default.conf
#Expose port
EXPOSE 80
#CMD declaration
CMD ["nginx", "-g", "daemon off;"]
