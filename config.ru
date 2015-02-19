require 'rubygems'
require 'rack'
require 'sinatra'
  
#set :run, false
set :environment, :production
#set :views, "views"
set :inline_templates, 'whoots.rb'
  
require './whoots.rb'
#run Sinatra::Application

