require "ruport"

require "active_record"
require "ruport/acts_as_reportable"

# Capistrano adds a REVISION file into the application's root directory, so
# we could think about testing its presence to tell the development and test
# environments apart.
production = File.exist?('REVISION')

if !production
  # Just to have a database in development mode.
  ActiveRecord::Base.establish_connection(:adapter  => 'sqlite3',
    :database => 'test.sqlite3', :timeout => 5000)

  # Sender of the email reports.
  @sender = 'noreply@example.com'

  # Array with the email addresses to which the email reports will be sent.
  @receivers = %w(me@localhost root@localhost)
else
  socket = ["/tmp/mysql.sock",
            "/tmp/mysqld.sock",
            "/var/lib/mysql/mysqld.sock",
            "/var/run/mysql/mysql.sock",
            "/var/run/mysqld/mysqld.sock"].detect{|socket|
              File.exist?(socket)
            }

  # Same values seen in Rails.
  ActiveRecord::Base.establish_connection(:adapter => 'mysql',
    :database => 'wonderful_application_db',
    :username => 'wonderful_application_user',
    :password => 'super_secret', :host => 'localhost', :socket => socket)

  # Sender of the email reports.
  @sender = 'noreply@example.com'

  # Array with the email addresses to which the email reports will be sent.
  @receivers = %w(someone@example.com someone.else@example.com)
end

# Time format used to display time information to users.
Time::DATE_FORMATS[:italian] = '%d/%m/%Y %H:%M:%S'
