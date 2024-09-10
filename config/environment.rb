require 'bundler/setup'
Bundler.require(:default)

# Configura la conexión a la base de datos
set :database, { adapter: 'sqlite3', database: 'db/database.sqlite3' }

# Carga todas las rutas del directorio app
Dir[File.join(File.dirname(__FILE__), '../app/models', '*.rb')].each { |file| require file }
