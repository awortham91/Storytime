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
  redirect '/index?page=0'
end

get "/index" do
  page = params['page']||0
  count = db_connection { |conn| conn.exec("SELECT count(stories.id) FROM entries
    FULL OUTER JOIN stories on entries.story_id = stories.id
    GROUP BY stories.id
    HAVING count(stories.id) < 8") }.to_a.count
  continues = db_connection { |conn| conn.exec("SELECT DISTINCT(stories.gif_url), stories.id, count(stories.id) FROM entries
    FULL OUTER JOIN stories on entries.story_id = stories.id
    GROUP BY stories.id
    HAVING count(stories.id) < 8
    OFFSET #{(page.to_i) * 8} LIMIT 8") }.to_a
  erb :index, locals: { continues: continues, count: count, page: params['page'] }
end

get "/index/completed" do
  page = params['page']||0
  count = db_connection { |conn| conn.exec("SELECT count(stories.id) FROM entries
    FULL OUTER JOIN stories on entries.story_id = stories.id
    GROUP BY stories.id
    HAVING count(stories.id) > 8") }.to_a.count
  continues = db_connection { |conn| conn.exec("SELECT DISTINCT(stories.gif_url), stories.id, count(stories.id) FROM entries
    FULL OUTER JOIN stories on entries.story_id = stories.id
    GROUP BY stories.id
    HAVING count(stories.id) > 8
    OFFSET #{(page.to_i) * 8} LIMIT 8") }.to_a
  erb :completed, locals: { continues: continues, count: count, page: params['page'] }
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
  num_of_entries = db_connection { |conn| conn.exec("SELECT * FROM entries WHERE story_id = #{params['story_id']}") }.to_a.size
  info = db_connection { |conn| conn.exec("SELECT stories.gif_url, stories.id, entries.entry FROM stories
    JOIN entries on stories.id = entries.story_id
    WHERE entries.story_id = #{params['story_id']}") }
 if num_of_entries >= 8
   notify = "That's it! The story is complete!"
 else
   notify = "The story so far"
 end
 erb :full, locals: { info: info.to_a, notify: notify }
end
