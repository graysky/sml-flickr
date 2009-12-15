#!/usr/bin/env ruby
require 'rubygems'
require 'xmlsimple'
require 'flickraw'

####
# SnapMyLife -> Flickr importer.
#
# Imports photos, title, desc, tags, geo data and created_at timestamp from
# the SML extracted zipfile to Flickr.
# 
# Warning: restarting will create duplicates if Flickr has issues.
#
# Requires xmlsimple and flickraw:
# > gem install xmlsimple flickraw
#
# Run from the same directory as the SML export that includes pictures and metadata.xml
# > ./sml-flickr.rb
####

# Flickr keys for snapmylife-flickr-importer
# http://www.flickr.com/services/apps/72157623002656216/
FlickRaw.api_key = "88920920fb333206f4639fa1cdb68a58"
FlickRaw.shared_secret = "5d92923e7d429139"

# "location"=>[{"radius"=>[{"type"=>"float", "content"=>"0.0"}],
# "latitude"=>[{"type"=>"float", "content"=>"42.369"}], 
# "longitude"=>[{"type"=>"float", "content"=>"-71.1527"}], 
def get_location(pic, key)
  return nil if pic.nil? || pic["location"].nil?
  
  loc = pic["location"].first
  
  val = loc[key]
  return nil if val.nil? || val.first.nil? || !val.first.has_key?("content")
  val.first["content"]
end

def get_value(hsh, key)
  x = hsh[key]
  
  val = nil
  val = x if x.class == String
  val = x.first if x.class == Array
  
  # Handle [{"nil"=>"true"}]
  val = nil if val.class == Hash
  
  val
end

# Do flickr auth
def flickr_auth
  frob = flickr.auth.getFrob
  auth_url = FlickRaw.auth_url :frob => frob, :perms => 'write'

  puts "Open this url in your browser to complete authentication: "
  puts "#{auth_url}"
  puts " "
  puts "Press Enter when you are finished."
  STDIN.getc

  begin
    flickr.auth.getToken(:frob => frob)
    login = flickr.test.login
    puts "You are now authenticated as #{login.username}"
    puts ""
  rescue FlickRaw::FailedResponse => e
    puts "Authentication failed : #{e.msg}"
    exit
  end
end

flickr_auth()

# pull in SML metadata
md = XmlSimple.xml_in('metadata.xml')

i = 0
# reverse_each
md["picture"].reverse_each do |pic|
  i = i + 1
  
  file = "#{pic['filename']}"
  title = get_value(pic, "title")
  desc = get_value(pic, "description")
  tags = pic["tags"].to_s
  
  puts "== Pic #{i} =="
  puts "File: #{file}"
  puts "Title: #{title}"
  puts "Desc: #{desc}"
  puts "Tags: #{tags}"
  
  is_public = 1
  
  # All to get a boolean...I blame Kevin. 
  if pic["is-private"].first["content"] == "true"
    is_public = 0
  end
  
  puts "Public: #{is_public}"

  # upload the photo
  resp = flickr.upload_photo(file, :title => title, :description => desc, :is_public => is_public, :tags => tags)
  photoid = resp.photoid
  puts "Problem with upload for #{file} (#{i})" if photoid.nil?
  
  sleep 1.0
  
  # Preserve the created at date
  taken_on = pic["created-at"].first["content"]
  puts "Taken on: #{taken_on}"
  flickr.photos.setDates(:photo_id => photoid, :date_taken => taken_on)
  
  lat = get_location(pic, "latitude")
  lng = get_location(pic, "longitude")
  
  puts "Lat: #{lat} Lng: #{lng}"
  
  if lat && lng
    # If there is geo, keep it
    flickr.photos.geo.setLocation(:photo_id => photoid, :lat => lat, :lon => lng)
  end
end

puts "Finished."