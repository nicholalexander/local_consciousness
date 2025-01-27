require 'socket'
require 'json'
require 'securerandom'

SERVER_HOST = '127.0.0.1'
SERVER_PORT = 4000

$stdout.sync = true

client = UDPSocket.new
client_id = SecureRandom.uuid

loop do
  payload = {
    time: Time.now.to_s,
    random_number: rand(1..100),
    client_id: client_id
  }

  client.send(payload.to_json, 0, SERVER_HOST, SERVER_PORT)
  puts "Sent: #{payload[:random_number]}"

  sleep 2  # Send a packet every 2 seconds
end
