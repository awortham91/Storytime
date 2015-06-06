require "sinatra"
require 'pg'
require 'pry'
require 'HTTParty'

def db_connection
  begin
    connection = PG.connect(dbname: "storytime")
    yield(connection)
  ensure
    connection.close
  end
end

get "/" do
  redirect '/index'
end

get "/index" do
  continues = db_connection { |conn| conn.exec("SELECT gif_url, id FROM stories") }
  erb :index, locals: { continues: continues}
end



get "/index/new" do

  giphy = HTTParty.get("http://api.giphy.com/v1/gifs/random?api_key=dc6zaTOxFJmzC")
  image = giphy['data']['image_url']

  erb :new, locals: { image: image }
end

post "/index/new" do
  story_bit = params['story_bit']
  id = db_connection { |conn| conn.exec_params("INSERT into stories(gif_url) VALUES ($1) RETURNING id", [params['image']]) }
  db_connection { |conn| conn.exec_params("INSERT into entries(story_id, entry) VALUES ($1, $2)", [id.to_a[0]['id'], story_bit]) }

redirect "index"
end

get "/story/:story_id" do
  info = db_connection { |conn| conn.exec("SELECT stories.gif_url, stories.id, entries.entry FROM entries
    FULL OUTER JOIN stories on entries.story_id = stories.id
    WHERE #{params['story_id']} = entries.story_id") }
  erb :story, locals: { info: info.to_a }
end

post "/story/:story_id" do
  db_connection { |conn| conn.exec_params("INSERT into entries(story_id, entry) VALUES ($1, $2)", [params['id'], params['story_bit']]) }
  redirect "/story/#{params['id']}/full"
end

get "/story/:story_id/full" do
  info = db_connection { |conn| conn.exec("SELECT stories.gif_url, stories.id, entries.entry FROM stories
    JOIN entries on stories.id = entries.story_id
    WHERE entries.story_id = #{params['story_id']}") }
  erb :full, locals: { info: info.to_a }
end
