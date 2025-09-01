FROM node:alpine

WORKDIR /usr/src/app

#Copy only package.json for dependency caching
COPY package*.json ./
RUN npm install

#Copying rest of the backend container content
COPY . .

#Expose the port used by Express
EXPOSE 3000

#Start the backend container
CMD ["node", "index.js"]
