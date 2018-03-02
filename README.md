# README #

PiWeatherStation (PiWS) is a small project developed to collect weather observations and aggregate them to
once-per-minute observations.  It includes firmware for the ATMega328 chip to read data from the sensors,
a Python service to run on a Raspberry Pi to read the serial data from the ATMega chip,
and a PostgreSQL database to store the raw observations.  Ansible is used to setup the Raspberry Pi and install the
PiWS services.

### How do I get set up? ###


* Summary of set up
* Configuration


#### Dependencies

* Ansible
* Git
* Arudino Temperature Control Library (Dallas Temperature)
* DHT library


#### Database Deployment

PiWS uses (Sqitch)[https://github.com/theory/sqitch]
to deploy and manage the PostgreSQL database.  


#### Deployment Instructions

Setup connection to database using environment variables.

```bash
export DB_HOST=127.0.0.1
export DB_USER=piws
export DB_NAME=piws
export DB_PW=SecurePassword
```


### Contribution guidelines ###

Coming soon...

* Writing tests
* Code review
* Other guidelines

### Getting Help

If you have questions, feel free to ask at support@rustprooflabs.com.

### Licensing

MIT
