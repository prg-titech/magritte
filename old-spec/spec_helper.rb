# -*- coding: utf-8 -*- #

require 'rubygems'
require 'bundler'
Bundler.require
require 'magritte'
require 'minitest/spec'
require 'minitest/autorun'

Dir[File.expand_path('support/**/*.rb', File.dirname(__FILE__))].each {|f|
  require f
}
