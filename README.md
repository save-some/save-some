# Save Some 

## What is it ? 
This is an application designed to help people save money. The high level 
overview is that by aggregating price histories for various products as 
well as allowing users to compare the same products across inventories, 
I can help someone save money.

## How to run it? 
Since Flutter supports many different environments there are a few ways
to run the application. To run the application in the browser use this
command. Note that the following commands are for starting the application
in a Unix environment. This hasn't been tested in a Windows environment 

```
flutter run -d web_server
```

Note that the MapBox map doesn't work in the browser since it isn't supported
yet. 

To run the application in an Android device emulator, first create an emulator 
in Android Studio. See 
[this](https://docs.flutter.dev/platform-integration/android/setup) link for 
more information. 

Once the emulator is created in Android Studio, launch it using this command. 

```
flutter emulators --launch <your_emulator_id> 
```

## How does it work? 
This application aggregates product information from various sources, namely
websites for common retailers like BJ's, Walmart, Best Buy, Home Depot etc and
uses the aggregated data to give users access to price histories, comparisons
and tracking capabilities. 

Currently data is fetched from RapidAPI but a web scraper would be where the 
data originates from. Then product information is batch written to the database
where the REST API forwards JSON to the Flutter frontnend based on the page in 
the application being accessed. 

## Tech Stack
Backend 
- Python 
- Supabase

Frontend
- Flutter

Deployment 
- AWS (Amazon Web Services)
- Nginx (Web Proxy)



## Version Control
- `main` - stable, demo-ready code
- `dev` - integration branch for merging features
- `experimental/{name}` - risky spikes, uncertain features
- `feature/{name}` - short-lived, merged into dev
- `bugfix/{name}` - fixes, merged into dev
- `fix/{name}` - fixes, merged into dev
- `maintenance/name` - maintenance, corresponds with issues

## Directory Structure
```
.
├── backend
│   ├── api
│   ├── helpers
│   ├── requirements.txt
│   ├── schema
│   └── seed
├── frontend
│   └── save-some-ui
└── README.md

```
