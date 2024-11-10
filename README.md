# Unify
SE Project

# Usage
## Correr la App
```
rackup
```

Abrir en un navegador el localhost:
```
http://127.0.0.1:9292
```

Cambiar de nombre el archivo <b> .envexample </b> por <b> .env </b>

Luego, agregar su propio token de OpenAI para que sea reconocido por la aplicación

Debería quedar algo como:
```
# Archivo .env
TOKEN_OPENAI='sk-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
```

# Instalaciones
## Tener ruby instalado

### Instalar Bundle
```
gem install bundler
```

### Instalar gemas
```
bundle install 
```

# Comandos para la base de datos
### Crear la base de datos
```
bundle exec rake db:create
```

### Eliminar la base de datos
```
bundle exec rake db:drop
```

### Migrar la base de datos
Migrar es una forma de decir impactar los cambios realizados hacia la base de datos

```
bundle exec rake db:migrate
```

# Testing: Rspec, Simplecov
Para correr los tests mencionados en la carpeta spec/
```
rspec
```

# Refactorización: Uso de Rubocop
La forma de revisar la refactorización del proyecto según la gema Rubocop es la siguiente:
```
bundle exec rubocop
```
Para automatizar pequeños detalles en la refactorización como por ejemplo intercambiar comillas simples por dobles, o espacios sobrantes, usar:
```
bundle exec rubocop -a
```

O también

```
bundle exec rubocop -A
```
