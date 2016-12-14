require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do

  def h(content)
    Rack::Utils.escape_html(content)
  end

  def all_checked?(list)
    !list[:todos].empty? && !list[:todos].any? { |todo| !todo[:completed] }
  end

  def item_completed?(item)
    item[:todos].nil? ? item[:completed] : all_checked?(item)
  end

  def list_class(list)
    'complete' if all_checked?(list)
  end

  def todos_remaining(list)
    "#{list[:todos].count { |todo| !todo[:completed] }}/#{list[:todos].size}"
  end

  def sort_items(items, &block)
    completed = {}
    incompleted = {}
    items.each_with_index do |item, idx|
      item_completed?(item) ? completed[item] = idx : incompleted[item] = idx
    end
    incompleted.each(&block)
    completed.each(&block)
  end
end

before do
  session[:lists] ||= []
end

def load_list(index)
  list = session[:lists][index]
  return list if list
  session[:error] = 'The specified list was not found.'
  redirect '/lists'
end

get '/' do
  redirect '/lists'
end

get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Rendering new list layout
get '/lists/new' do
  erb :new_list, layout: :layout
end
# View a single list
get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

def error_for_list_name(name)
  if !(1..100).cover? name.size
    'List name must be between 1 and 100 characters.'
  elsif !!(name =~ /[^A-Za-z0-9!.,\? ]/)
    'List name may only contain letters, numbers, and common punctuation.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

def error_for_todo(name)
  if !(1..100).cover?(name.size)
    'Todo must be between 1 and 100 characters.'
  elsif !!(name =~ /[^A-Za-z0-9!.,\? ]/)
    'Todo name may only contain letters, numbers, and common punctuation.'
  end
end

# Create a new list
post '/lists/new' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# edit an existing list
get '/lists/:id/edit' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout
end

# update an existing list
post '/lists/:id/edit' do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated.'
    redirect '/lists/#{id}'
  end
end

# Delete a list
post '/lists/:id/destroy' do
  id = params[:id].to_i
  session[:lists].delete_at id
  session[:success] = 'The list has been deleted.'
  redirect '/lists'
end

# Update the status of a todo
post '/lists/:list_id/todos/:todo_num/check' do
  todo_num = params[:todo_num].to_i
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  is_completed = params[:completed] == 'true'
  @list[:todos][todo_num][:completed] = is_completed
  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@list_id}"
end

# Check-off all to-dos
post '/lists/:list_id/check_all' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = 'All todos have been completed.'
  redirect "/lists/#{@list_id}"
end

# Delete a todo from a list
post '/lists/:list_id/todos/:todo_num/destroy' do
  todo_num = params[:todo_num].to_i
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @list[:todos].delete_at todo_num
  session[:success] = 'The todo has been deleted.'
  redirect "/lists/#{@list_id}"
end

# Add a new todo to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: params[:todo], completed: false }
    session[:success] = 'The todo was added.'
    redirect "/lists/#{@list_id}"
  end
end
