#!/usr/bin/env ruby

require 'httparty'
require 'json'
require 'nokogiri'

class CodeBase
  def initialize
    @all_code = []
    if File.exist?('code.json')
      @all_code = JSON.parse(File.read('code.json'))
    end
    if @all_code.length == 0
      update_all_code
    end
  end

  def query_code(city_name, town_name = nil)
    city_name = city_name.gsub('臺', '台')
    if town_name
      town_name = town_name.gsub('臺', '台')
    end
    city_code = nil
    town_code = nil
    @all_code.each do |city|
      if city['name'] == city_name
        city_code = city['code']
        town_code = query_town_code(city['towns'], town_name)
        if town == nil or town_code != nil
          break
        end
      end
    end
    return [city_code, town_code]
  end

  def query_town_code(town_list, town_name = nil)
    town_code = nil
    if town_name
      town_list.each do |town|
        if town_name == town['name']
          town_code = town['code']
        end
      end
    end
    return town_code
  end

  def update_all_code
    @all_code = get_all_code
    File.open("code.json","w") do |f|
      f.write(JSON.pretty_generate(@all_code))
    end
  end

  def get_page(url, params = {})
    response = HTTParty.post(url, body: params, headers: { 'Content-Type' => 'application/json' })
    if response.code == 200
      return response.body
    else
      return false
    end
  end

  def get_cities_code
    url = "http://210.241.18.213/API/NationalLandBasicCode/QueryBasicCode"
    params = { Querytype: "查詢縣市" }.to_json
    result = JSON.parse(get_page(url, params))
    return result["LIServiceRsgMsg"]["Response"]["CITY"].map { |city| {name: city["NAME"].gsub('臺', '台'), code: city["CODE"]} }
  end

  def get_towns_code(city_code)
    url = "http://210.241.18.213/API/NationalLandBasicCode/QueryBasicCode"
    params = { Querytype: "查詢鄉鎮", CITY: city_code }.to_json
    result = JSON.parse(get_page(url, params))
    result = result["LIServiceRsgMsg"]["Response"]
    if result == nil
      result = []
    elsif result["TOWN"].kind_of?(Array)
      result = result["TOWN"].map { |town| {name: town["NAME"].gsub('臺', '台'), code: town["CODE"]} }
    else
      result = [{name: result["TOWN"]["NAME"], code: result["TOWN"]["CODE"]}]
    end
    result
  end

  def get_units_code(city_code)
    url = "http://210.241.18.213/API/NationalLandBasicCode/QueryBasicCode"
    params = { Querytype: "查詢事務所", CITY: city_code }.to_json
    result = JSON.parse(get_page(url, params))
    result = result["LIServiceRsgMsg"]["Response"]
    if result == nil
      result = []
    elsif result["UNIT"].kind_of?(Array)
      result = result["UNIT"].map { |unit| {name: unit["NAME"], code: unit["CODE"]} }
    else
      result = [{name: result["UNIT"]["NAME"], code: result["UNIT"]["CODE"]}]
    end
    result
  end

  def get_all_code
    cities = get_cities_code
    cities = cities.map do |city|
      city[:towns] = get_towns_code(city[:code])
      city[:units] = get_units_code(city[:code])
      city
    end
    return cities
  end
end


