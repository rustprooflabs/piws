# Pi Weather Station (PiWS) Project README

PiWeatherStation (PiWS) is an open-source project developed to collect weather,
and other sensor related observations,
and aggregate them to once-per-minute observations.  This project includes
firmware for the ATMega328 chip to read data from the sensors,
a Python service to run on a Raspberry Pi to read the serial data from the ATMega chip,
and a PostgreSQL database to store the raw observations.  An optional service
to send data to the sensor data API

Ansible is used to setup the Raspberry Pi and install the
PiWS services.


## Dependencies

* Ansible
* Git
* Arudino Temperature Control Library (Dallas Temperature)
* DHT library
* PostgreSQL 9.5 +
* Python
* [PostgreSQL Data Dictionary (pgdd)](https://github.com/rustprooflabs/pgdd)


### Will you support older version of PostgreSQL than 9.5?

No.  The data loading code uses `ON CONFLICT` and requires PostgreSQL 9.5 or
later.

## Setting Up


* Summary of set up
* Configuration


### Database Deployment

PiWS uses (Sqitch)[https://github.com/theory/sqitch]
to deploy and manage the PostgreSQL database.


### Dev Deployment Instructions

To run the PiWS, setup connection to database using environment variables.


```bash
source ~/venv/piws/bin/activate

cd ~/git/piws

export DB_HOST=127.0.0.1
export DB_USER=piws
export DB_NAME=piws
export DB_PW=SecurePassword
export APP_LOG_LEVEL=DEBUG

# Options expanded/standard.  Default is expanded
#export PIWS_SCB_CONFIGURATION=expanded

python run_station.py

```

```bash
source ~/venv/piws/bin/activate
export DB_HOST=127.0.0.1
export DB_USER=piws
export DB_NAME=piws
export DB_PW=SecurePassword
export API_HOST=http://127.0.0.1:5000
export TYG_API_KEY=YourAPIKeyHere
export TYG_SENSOR_ID=0

python send_to_api.py
```

#### Env Var for Expanded SCB

```bash
export PIWS_SCB_CONFIGURATION=expanded
```

### Manual Database deployments

For testing purposes:

```bash
PGOPTIONS='-c search_path=piws,public' sqitch deploy db:pg://piws:yourpassword@127.0.0.1:5432/piws
```


## Unit tests w/ Coverage

```bash
source ~/venv/piws/bin/activate
cd  /media/sf_git/piws
coverage run -m unittest tests/*.py

```

## Licensing

MIT


## Contribution guidelines

Coming soon...

* Writing tests
* Code review
* Other guidelines

## Getting Help

If you have questions, feel free to email RustProof Labs at support@rustprooflabs.com
or use [our contact form](https://www.rustprooflabs.com/contact).

