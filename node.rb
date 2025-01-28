require 'socket'
require 'json'
require 'time'

SERVER_HOST = '127.0.0.1'
SERVER_PORT = 4000

$stdout.sync = true

def generate_random_bits
  Array.new(200) { rand(0..1) }.join('').to_i
end

def client_id
  @client_id ||= "node_#{rand(1000..9999)}"
end

client = UDPSocket.new

puts "Starting UDP client with ID: #{client_id}"

loop do
  random_bits = generate_random_bits
  payload = {
    client_id: client_id,
    timestamp: Time.now.utc.iso8601,
    random_bits: random_bits
  }

  client.send(payload.to_json, 0, SERVER_HOST, SERVER_PORT)
  puts "Sent: #{payload}"

  sleep 1
end
