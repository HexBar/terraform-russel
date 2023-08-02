from flask import Flask, request, jsonify
from flask_cors import CORS
import psycopg2
import json
import os 

app = Flask(__name__)
CORS(app)


db_host = "10.0.1.10"
db_port = 5432
db_name = "weighttrackerdb"
db_user = "bar"
db_password = os.environ.get("DB_PASSWORD", "")

def create_connection():
    conn = psycopg2.connect(
        host=db_host,
        port=db_port,
        database=db_name,
        user=db_user,
        password=db_password
    )
    return conn

@app.route("/")
def hello_world():
    return "Hello World"

@app.route("/data", methods=["GET"])
def get_data():
    try:
        conn = create_connection()
        cur = conn.cursor()

        # Fetch data from the database
        cur.execute("SELECT * FROM data")
        rows = cur.fetchall()

        cur.close()
        conn.close()

        # Convert data to JSON format
        data = []
        for row in rows:
            data.append({
                "name": row[0],
                "weight_value": row[1],
                "time": row[2].strftime("%Y-%m-%d %H:%M:%S")
            })

        return jsonify(data)
    except (Exception, psycopg2.Error) as error:
        print("Error while connecting to PostgreSQL", error)
        return jsonify({"error": "Failed to fetch data"})


@app.route("/data", methods=["POST"])
def store_data():
    data = request.get_json()
    name = data["name"]
    weight_value = data["weight_value"]
    time = data["time"]

    try:
        conn = create_connection()
        cur = conn.cursor()

        # Insert data into the database
        cur.execute("INSERT INTO data (name, weight_value, mytime) VALUES (%s, %s, %s)", (name, weight_value, time))
        conn.commit()

        cur.close()
        conn.close()

        return jsonify({"message": "Data stored successfully"})
    except (Exception, psycopg2.Error) as error:
        print("Error while connecting to PostgreSQL", error)
        return jsonify({"error": "Failed to store data"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
