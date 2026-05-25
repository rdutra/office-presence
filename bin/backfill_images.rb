# frozen_string_literal: true

require_relative "../lib/office_presence"
require_relative "../lib/office_presence/database"
require_relative "../lib/office_presence/models/person"

db = OfficePresence::Database.connection
person_model = OfficePresence::Models::Person.new(db)

sticker_data = [
  {"name" => "Federico Jaeggi", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Federico%20Jaeggi.jpg"},
  {"name" => "Ezequiel Bar Coch", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Ezequiel%20Bar%20Coch.jpg"},
  {"name" => "Gabriel Polo Brallard", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Gabriel%20Polo%20Brallard.jpg"},
  {"name" => "Pablo Anello", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Pablo%20Anelo.jpg"},
  {"name" => "Juan Castellano", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Juan%20Castellano.jpg"},
  {"name" => "Alejandro Gomez", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Alejandro%20Gomez.jpg"},
  {"name" => "Javier Delmastro", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Javier%20Delmastro.jpg"},
  {"name" => "Leandro Tealdi", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Leandro%20Tealdi.jpg"},
  {"name" => "Andrés Aguirre", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Andres%20Aguirre.jpg"},
  {"name" => "Ramiro Díaz", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Ramiro%20Diaz.jpg"},
  {"name" => "Facundo Morales", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Facundo%20Morales.jpg"},
  {"name" => "Benjamin Lizarraga", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Benjamin%20Lizarraga.jpg"},
  {"name" => "Melani Lopez", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Melani%20Lopez.jpg"},
  {"name" => "Diego Robledo", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Diego%20Robledo.jpg"},
  {"name" => "Gerardo Britos", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Gerardo%20Britos.jpg"},
  {"name" => "Juan Rodriguez", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Juan%20Rodriguez.jpg"},
  {"name" => "Cecilia Marcora", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Cecilia%20Marcora.jpg"},
  {"name" => "Damian Salaverry", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Damian%20Salaverry.jpg"},
  {"name" => "Diego Pedemonte", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Diego%20Pedemonte.jpg"},
  {"name" => "German Pereyra", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/German%20Pereyra.jpg"},
  {"name" => "Andres Segurola", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Andres%20Segurola.jpg"},
  {"name" => "Fernando Casalongue", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Fernando%20Casalongue.jpg"},
  {"name" => "Leon Barboza", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Leon%20Barboza.jpg"},
  {"name" => "Ignacio Facello", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Ignacio%20Facello.jpg"},
  {"name" => "Gabriel Osorio", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Gabriel%20Osorio.jpg"},
  {"name" => "Rodrigo Dutra", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Rodrigo%20Dutra.jpg"},
  {"name" => "Daniel Lopez", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Daniel%20Lopez.jpg"},
  {"name" => "Rodrigo Machado", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Rodrigo%20Machado.jpg"},
  {"name" => "Fernando Ramos", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Fernando%20Ramos.jpg"},
  {"name" => "Maru Algorta", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Maru%20Algorta.jpg"},
  {"name" => "Sebastian Sierra", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Sebastian%20Sierra.jpg"},
  {"name" => "Mauricio Souto", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Mauricio%20Souto.jpg"},
  {"name" => "Ana Tamayo", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Ana%20Tamayo.jpg"},
  {"name" => "Victoria Bentos", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Victoria%20Bentos.jpg"},
  {"name" => "Gabriel Barbatto", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Gabriel%20Barbatto.jpg"},
  {"name" => "Alejandro Costa", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Alejandro%20Costa.jpg"},
  {"name" => "Agustin Sivoplas", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Agustin%20Sivoplas.jpg"},
  {"name" => "Pedro Neyeloff", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Pedro%20Neyeloff.jpg"},
  {"name" => "Juan Peon", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Juan%20Peon.jpg"},
  {"name" => "Gonzalo Arreche", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Gonzalo%20Arreche.jpg"},
  {"name" => "Guillermo Del Fresno", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Guillermo%20Del%20Fresno.jpg"},
  {"name" => "Marcelo Bevegni", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Marcelo%20Bevegni.jpg"},
  {"name" => "Juan Manuel San Martin", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Juan%20Manuel%20San%20Martin.jpg"},
  {"name" => "Gonzalo Robaina", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Gonzalo%20Robaina.jpg"},
  {"name" => "Julio Pintos", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Julio%20Pintos.jpg"},
  {"name" => "Guillermo Coll", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Guillermo%20Coll.jpg"},
  {"name" => "Iuval Goldansky", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Iuval%20Goldansky.jpg"},
  {"name" => "Gaston Cerrillo", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Gaston%20Cerrillo.jpg"},
  {"name" => "Ricardo Umpierrez", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Ricardo%20Umpierrez.jpg"},
  {"name" => "Gonzalo Puentes", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Gonzalo%20Puentes.jpg"},
  {"name" => "Mathias Braga", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Mathias%20Braga.jpg"},
  {"name" => "Alejandro Fernandes Antunes", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Alejandro%20Fernandes%20Antunes.jpg"},
  {"name" => "Juan Olivera", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Juan%20Olivera.jpg"},
  {"name" => "Oscar Siniscalchi", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Oscar%20Siniscalchi.jpg"},
  {"name" => "Diego Curbelo", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Diego%20Curbelo.jpg"},
  {"name" => "Rodrigo Ordeix", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Rodrigo%20Ordeix.jpg"},
  {"name" => "Gonzalo Melgar", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Gonzalo%20Melgar.jpg"},
  {"name" => "Gonzalo Gelos", "image_url" => "https://www.tarmac.io/hubfs/Tarmac_December_2021/images/Team%20Member/Gonzalo%20Gelos.jpg"}
]

puts "Backfilling image URLs..."

aliases = {
  "mauri souto" => "Mauricio Souto",
  "vicky" => "Victoria Bentos",
  "chechu" => "Cecilia Marcora",
  "nando" => "Fernando Casalongue",
  "juanb" => "Juan Boggia",
  "gaston" => "Gaston Cerrillo"
}

sticker_data.each do |data|
  name_normalized = data["name"].downcase.strip
  
  # 1. Try exact match
  db[:people].where(Sequel.function(:lower, Sequel.function(:trim, :person)) => name_normalized).update(image_url: data["image_url"])
  
  # 2. Try alias match
  aliases.each do |db_name, full_name|
    if full_name.downcase == name_normalized
      db[:people].where(Sequel.function(:lower, Sequel.function(:trim, :person)) => db_name).update(image_url: data["image_url"])
    end
  end

  # 3. Try partial match (if DB name is a subset of the full name)
  # Be careful with short names like "Alice" or "Flor"
  db[:people].all.each do |row|
    person_name = row[:person].to_s.downcase.strip
    if person_name.length > 3 && name_normalized.include?(person_name)
      db[:people].where(mac: row[:mac]).update(image_url: data["image_url"])
    end
  end
end

puts "Done."
