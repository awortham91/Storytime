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
  num_of_entries_per_gif = db_connection { |conn| conn.exec("SELECT stories.id AS story_id, stories.gif_url AS gif_url,
    (SELECT COUNT(*) FROM entries WHERE entries.story_id = stories.id) AS entries_count FROM stories") }.to_a
    binding.pry

  unfinished_stories = []
  finished_stories = []

  num_of_entries_per_gif[0].each do |entry|
    if entry['entries_count'] < 10
      unfinished_stories << entry['story_id']
    else
      finished_stories << entry['story_id']
    end
  end

  # NEED TO FINISH FIGURING OUT HOW TO SEPARATE FINISHED AND UNFINISHED STORIES

  continues = db_connection { |conn| conn.exec("SELECT gif_url, id FROM stories") }.to_a.reverse

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
  num_of_entries = db_connection { |conn| conn.exec("SELECT * FROM entries WHERE story_id = #{params['id']}") }.to_a.size

  if num_of_entries < 10
    db_connection { |conn| conn.exec_params("INSERT into entries(story_id, entry) VALUES ($1, $2)", [params['id'], params['story_bit']]) }
    redirect "/story/#{params['id']}/full"
  else
    redirect "/story/#{params['id']}/full" #Should redirect to Completed Stories Page
  end
end

get "/story/:story_id/full" do
  num_of_entries = db_connection { |conn| conn.exec("SELECT * FROM entries WHERE story_id = #{params['story_id']}") }.to_a.size

  info = db_connection { |conn| conn.exec("SELECT stories.gif_url, stories.id, entries.entry FROM stories
    JOIN entries on stories.id = entries.story_id
    WHERE entries.story_id = #{params['story_id']}") }

  if num_of_entries >= 10
    notify = "That's it! The story is complete!"
    erb :full, locals: { info: info.to_a, notify: notify }
  else
    notify = "The story so far"
    erb :full, locals: { info: info.to_a, notify: notify }
  end

end
