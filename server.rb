require 'socket'
require 'json'
require 'sqlite3'
require 'time'
require 'thread'
require 'pry'

PORT = 4000

$stdout.sync = true

DB_FILE = 'rng_data.db'

def setup_database
  db = SQLite3::Database.new(DB_FILE)
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS rng_data (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      random_bits TEXT NOT NULL
    );
  SQL
  db
end

def insert_data(db, client_id, timestamp, random_bits)
  db.execute("INSERT INTO rng_data (client_id, timestamp, random_bits) VALUES (?, ?, ?)", [client_id, timestamp, random_bits])
end

def compute_variance(random_bits)
  bits = random_bits.chars.map(&:to_i)
  mean = bits.sum.to_f / bits.size
  variance = bits.map { |b| (b - mean)**2 }.sum / bits.size
  variance
end

def compute_z_scores(data)
  return [] if data.empty?

  variances = data.map { |row| row[:variance] }
  mean = variances.sum / variances.size
  stddev = Math.sqrt(variances.map { |v| (v - mean)**2 }.sum / (variances.size - 1))

  data.each do |row|
    row[:z_score] = (row[:variance] - mean) / stddev
  end
end

def aggregate_z_score(data)
  return 0 if data.empty?

  sum_z = data.map { |entry| entry[:z_score] }.sum
  sum_z / Math.sqrt(data.size)
end

puts "Setting up database..."
db = setup_database
puts "Database initialized."

server = UDPSocket.new
server.bind('0.0.0.0', PORT)

puts "UDP server is listening on port #{PORT}..."

db_mutex = Mutex.new

# Analysis thread
Thread.new do
  loop do
    sleep 10

    db_mutex.synchronize do
      begin
        ten_seconds_ago = (Time.now - 10).utc.iso8601
        rows = db.execute("SELECT client_id, timestamp, random_bits FROM rng_data WHERE timestamp >= ?", [ten_seconds_ago])

        data = rows.map do |row|
          {
            client_id: row[0],
            timestamp: row[1],
            random_bits: row[2],
            variance: compute_variance(row[2])
          }
        end

        compute_z_scores(data)

        cumulative_z = aggregate_z_score(data)

        puts "\nAnalysis Report (Last 10 Seconds):"
        puts "--------------------------------"
        puts "Total Entries: #{data.size}"
        data.each do |entry|
          puts "Client: #{entry[:client_id]} | Z-Score: #{entry[:z_score].round(3)} | Variance: #{entry[:variance].round(5)}"
        end
        puts "Cumulative Z-Score: #{cumulative_z.round(3)}"
        puts "--------------------------------\n"
      rescue SQLite3::Exception => e
        puts "Database error during analysis: #{e.message}"
      rescue => e
        puts "Unexpected error during analysis: #{e.message}"
        binding.pry
      end
    end
  end
end

loop do
  message, _addr = server.recvfrom(1024)
  begin
    data = JSON.parse(message, symbolize_names: true)
    client_id = data[:client_id]
    timestamp = data[:timestamp]
    random_bits = data[:random_bits]

    puts "#{client_id}: #{data}"

    db_mutex.synchronize do
      insert_data(db, client_id, timestamp, random_bits)
    end
  rescue JSON::ParserError
    puts "Invalid JSON received: #{message}"
  rescue SQLite3::Exception => e
    puts "Database error: #{e.message}"
  end
end
