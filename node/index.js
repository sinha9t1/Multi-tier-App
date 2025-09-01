import 'dotenv/config';
import pg from 'pg';
import express from 'express';

const { Client } = pg;

const client = new Client({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

client.connect()
  .then(() => console.log('✅ Connected to Postgres DB'))
  .catch(err => console.error('❌ DB connection error:', err.stack));

const createTable = async () => {
    await client.query(`CREATE TABLE IF NOT EXISTS users
    (id serial PRIMARY KEY, name VARCHAR (255) UNIQUE NOT NULL,
    email VARCHAR (255) UNIQUE NOT NULL, age INT NOT NULL);`)
};
createTable();

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/api', (req, res) => res.send('Hello World!'));

app.get('/api/all', async (req, res) => {
    try {
      const response = await client.query(`SELECT * FROM users`);
      if(response){
        res.status(200).send(response.rows);
      }
    } catch (error) {
      res.status(500).send(error);
      console.log(error);
    }
});

app.post('/api/form', async (req, res) => {
    try {
      const name  = req.body.name;
      const email = req.body.email;
      const age   = req.body.age;
      // Fixed the typo: 'ag' -> 'age'
      const response = await client.query(`INSERT INTO users(name, email, age) VALUES ('${name}', '${email}', ${age});`);
      if(response){
        res.status(200).send(req.body);
      }
    } catch (error) {
      res.status(500).send(error);
      console.log(error);
    }
});

app.listen(5000, '0.0.0.0', () => console.log(`App running on port 5000.`));
