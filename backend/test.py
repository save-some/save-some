import requests
import os

value = os.getenv('API')

url = "https://walmart-data.p.rapidapi.com/walmart-category.php"

querystring = {"url":"https://www.walmart.com/browse/electronics/3944"}

headers = {
	"x-rapidapi-key": value,
	"x-rapidapi-host": "walmart-data.p.rapidapi.com", 
	"Content-Type": "application/json"
}

response = requests.get(url, headers=headers, params=querystring)

print(response.status_code)
print(response.json())




