#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <EEPROM.h>
#include <ArduinoJson.h>
#include <PubSubClient.h>
#include <DHT.h>

#define DHTPIN D4
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);
#define RESET_BUTTON_PIN D8 // GPIO0
#define LONG_PRESS_DURATION 5000 // 5 seconds

ESP8266WebServer server(80);
WiFiClient espClient;
PubSubClient mqttClient(espClient);

const char* mqtt_server = "broker.hivemq.com";

// EEPROM storage locations
#define EEPROM_SIZE 512
#define SSID_ADDR 0
#define PASS_ADDR 100
#define NAME_ADDR 200

String deviceName = "ThermoSensor";

// Save Wi-Fi credentials to EEPROM
void saveCredentials(String ssid, String password, String deviceId) {
  EEPROM.begin(EEPROM_SIZE);
  for (int i = 0; i < 100; i++) {
    EEPROM.write(SSID_ADDR + i, i < ssid.length() ? ssid[i] : 0);
    EEPROM.write(PASS_ADDR + i, i < password.length() ? password[i] : 0);
    EEPROM.write(NAME_ADDR + i, i < deviceId.length() ? deviceId[i] : 0);
  }
  EEPROM.commit();
  EEPROM.end();
}


// Load Wi-Fi credentials from EEPROM
bool loadCredentials(char* ssid, char* password, char* name) {
  EEPROM.begin(EEPROM_SIZE);
  for (int i = 0; i < 100; i++) {
    ssid[i] = EEPROM.read(SSID_ADDR + i);
    password[i] = EEPROM.read(PASS_ADDR + i);
    name[i] = EEPROM.read(NAME_ADDR + i);
  }
  ssid[99] = password[99] = name[99] = '\0';
  EEPROM.end();
  return strlen(ssid) > 0 && strlen(password) > 0;
}

// Handle POST /provision
#include <stdlib.h>

// Generate 10-digit random ID
String generateRandomDeviceId() {
  String id = "";
  for (int i = 0; i < 10; i++) {
    id += String(random(0, 10));
  }
  return id;
}

// Handle POST /provision
void handleProvision() {
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"error\":\"Missing body\"}");
    return;
  }

  StaticJsonDocument<256> doc;
  DeserializationError error = deserializeJson(doc, server.arg("plain"));
  if (error) {
    server.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
    return;
  }

  String ssid = doc["ssid"];
  String pass = doc["password"];

  String deviceId = generateRandomDeviceId();
  saveCredentials(ssid, pass, deviceId);

  StaticJsonDocument<128> res;
  res["status"] = "success";
  res["deviceId"] = deviceId;

  String response;
  serializeJson(res, response);

  server.send(200, "application/json", response);
  delay(1000);
  ESP.restart();
}

// Start AP mode for provisioning
void startAPMode() {
  WiFi.mode(WIFI_AP);
  WiFi.softAP("ThermoSensor-Setup");

  server.on("/provision", HTTP_POST, handleProvision);
  server.begin();
  Serial.println("AP Mode: 192.168.4.1");

  while (true) {
    server.handleClient();
  }
}

// Connect to Wi-Fi using saved credentials
bool connectToWiFi() {
  char ssid[100], pass[100], name[100];
  if (!loadCredentials(ssid, pass, name)) return false;

  deviceName = String(name);
  WiFi.begin(ssid, pass);
  Serial.printf("Connecting to %s", ssid);

  for (int i = 0; i < 20; i++) {
    if (WiFi.status() == WL_CONNECTED) return true;
    delay(500);
    Serial.print(".");
  }
  Serial.println("Failed");
  return false;
}

// Reconnect MQTT
void reconnectMQTT() {
  while (!mqttClient.connected()) {
    if (mqttClient.connect(deviceName.c_str())) {
      Serial.println("MQTT connected");
    } else {
      delay(2000);
    }
  }
}

void clearEEPROM() {
  EEPROM.begin(EEPROM_SIZE);
  for (int i = 0; i < EEPROM_SIZE; i++) {
    EEPROM.write(i, 0);
  }
  EEPROM.commit();
  EEPROM.end();
  Serial.println("EEPROM cleared");
}

void setup() {
  Serial.begin(115200);
  dht.begin();

  pinMode(RESET_BUTTON_PIN, INPUT_PULLUP);

  unsigned long pressStart = millis();
  bool longPressed = false;

  while (digitalRead(RESET_BUTTON_PIN) == LOW) {
    if (millis() - pressStart > LONG_PRESS_DURATION) {
      longPressed = true;
      break;
    }
    delay(100);
  }

  if (longPressed) {
    Serial.println("Long press detected. Clearing EEPROM...");
    clearEEPROM();
    delay(1000);
    startAPMode(); // Go to provisioning mode
  }

  if (!connectToWiFi()) {
    startAPMode(); // fallback if WiFi fails
  }

  mqttClient.setServer(mqtt_server, 1883);
}


void loop() {
  if (!mqttClient.connected()) {
    reconnectMQTT();
  }
  mqttClient.loop();

  float temp = dht.readTemperature();
  float hum = dht.readHumidity();

  if (!isnan(temp) && !isnan(hum)) {
    String payload = String(temp, 1) + "," + String(hum, 1);
    String topic = deviceName + "/data";
    mqttClient.publish(topic.c_str(), payload.c_str());
    Serial.println("Published: " + payload);
  }

  delay(60000);  // 1 minute delay
}
