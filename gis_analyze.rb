# coding: utf-8
require 'optparse' # オプション解析
require 'pry'

Encoding.default_external = 'utf-8'
Encoding.default_internal = 'utf-8'

# def get_curve_pos(kml,station_data,rail)
#   curves = station_data[:curves]
#   if curves.key? rail[:location]
#     kml.push '<LineString>'
#     kml.push '<coordinates>'
#     curve_pos_array = curves[rail[:location]]
#     curve_pos_array.each do |pos|
#       kml.push "#{pos[:lat]},#{pos[:lng]},0.0"
#     end
#     kml.push '</coordinates>'
#     kml.push '</LineString>'
#   else
#     puts "ERROR: カーブデータに #{rail[:location]} がない。".encode('cp932')
#   end
# end


# def get_curve(kml,station_data,key,station_name)
#   curves = station_data[:curves]
#   rails = station_data[key]
#   rails.each do |id,rail|
#     if rail[:railway_line_name] =~ /^#{station_name}$/
#       get_curve_pos(kml,station_data,rail)
#       # 駅リンクがあるか確認
#       if rail.key? :station
#         stations = station_data[:stations]
#         if stations.key? rail[:station]
#           get_curve_pos(kml,station_data,stations[rail[:station]]);
#         else
#           puts "ERROR: 駅データに #{rail[:station]} がない。".encode('cp932')
#         end
#       end
#     end
#   end
# end

def get_curve_pos(station_data,rail)
  curves = station_data[:curves]
  if curves.key? rail[:location]
    return curves[rail[:location]]
  else
    puts "ERROR: カーブデータに #{rail[:location]} がない。".encode('cp932')
  end
end


def get_curve(station_data,key,station_name)
  out_curves = Array.new # １路線のカーブ情報保持
  curves = station_data[:curves]
  rails = station_data[key]
  rails.each do |id,rail|
    # puts "#{rail[:railway_line_name]} #{station_name}".encode('cp932')
    if rail[:railway_line_name] == station_name
      out_curves << get_curve_pos(station_data,rail)
      # # 駅リンクがあるか確認
      # if rail.key? :station
      #   stations = station_data[:stations]
      #   if stations.key? rail[:station]
      #     out_curves << get_curve_pos(station_data,stations[rail[:station]]);
      #   else
      #     puts "ERROR: 駅データに #{rail[:station]} がない。".encode('cp932')
      #   end
      # end
    end
  end
  return out_curves
end

def create_kml(station_data)
  kml = Array.new
  
  kml.push '<?xml version="1.0" encoding="UTF-8"?>'
  kml.push '<kml xmlns="http://www.opengis.net/kml/2.2">'
  kml.push '<Document>'
  kml.push '<name>kml</name>'
  kml.push '<open>1</open>'

  # 路線名取得
  rail_hash = Hash.new
  station_data[:rail_roads].each do |id,rail|
    key = rail[:railway_line_name] + rail[:operation_company]
    if ! rail_hash.key? key
      rail_hash[key] = rail
      # puts "#{key}".encode('cp932')
    end
  end

  # rail_hash = Hash.new
  # hash = {
  #   :railway_line_name => '4号線(中央線)',
  #   :operation_company => '大阪市'
  # }
  # rail_hash[:test] = hash
  
  # カーブデータ出力
  rail_hash.each do |key,rail| 
    curves = get_curve(station_data,:rail_roads,rail[:railway_line_name])
    curves.each do |curve|
      kml.push '<Placemark>'
      kml.push '<description>'+rail[:operation_company]+'</description>'
      kml.push '<name>'+rail[:railway_line_name]+'</name>'
      kml.push '<LineString>'
      kml.push '<coordinates>'
      curve.each do |pos|
        kml.push "#{pos[:lat]},#{pos[:lng]},0.0"
      end
      kml.push '</coordinates>'
      kml.push '</LineString>'
      kml.push '</Placemark>'
    end
  end
  
  kml.push '</Document>'
  kml.push '</kml>'
  return kml
end


puts "get_station_info version.0.2015.05.12.0945"
inparam = Hash.new # 入力情報保持用

# オプション解析用パーサー生成
opt = OptionParser.new
opt.on('-d', '--debug') {|val| inparam[:debug] = true }

argv = opt.parse(ARGV)
if argv.length != 2 then
    puts "usage get_station_info <xml path> <outfile path>"
    puts " [options] -d : debug mode"
    exit
end

stationData = Hash.new
begin
  file = File.open(argv[0], "r:BOM|UTF-8")
  file_body = file.read
  
  # 不要なヘッダ削除
  file_body.gsub!(/\<\?xml version=\"1\.0\" encoding\=\"UTF\-8\" \?\>/) { "# xml" }
  file_body.gsub!(/\<ksj\:Dataset gml\:id=\".+?\".+?\>/m) { "# ksj:Dataset" }
  file_body.gsub!(/\<\/ksj\:Dataset\>/) { "# \/ksj:Dataset" }
  
  # タイトル取得
  file_body.gsub!(/\<gml\:description\>(.+?)\<\/gml\:description\>/m) do
    stationData[:description] = $1
    "# gml:description"
  end

  # バウンドデータ取得
  bound = Hash.new
  file_body.gsub!(/\<gml\:boundedBy\>.+?\<gml\:EnvelopeWithTimePeriod srsName\=\"(.+?)\" frame\=\"(.+?)\"\>(.+?)\<\/gml\:EnvelopeWithTimePeriod\>.+?\<\/gml\:boundedBy\>/m) do
    bound[:src_name] = $1
    bound[:frame] = $2
    body = $3
    if body =~ /\<gml\:lowerCorner\>([0-9\.]+?)\s+([0-9\.]+?)\<\/gml\:lowerCorner\>/
      pos = { :lat => $1, :lng => $2}
      bound[:lower_corner] = pos
    end
    if body =~ /\<gml\:upperCorner\>([0-9\.]+?)\s+([0-9\.]+?)\<\/gml\:upperCorner\>/
      pos = { :lat => $1, :lng => $2}
      bound[:upper_corner] = pos
    end
    if body =~ /\<gml\:beginPosition calendarEraName\=\"(.+?)\"\>(\d+?)\<\/gml\:beginPosition\>/
      hash = { :calendar_era_name => $1, :year => $2}
      bound[:bigin_position] = hash
    end
    if body =~ /\<gml\:endPosition indeterminatePosition=\"(.+?)\"\/\>/
      hash = { :indeterminate_position => $1 }
      bound[:end_position] = hash
    end
    "# bml:boundedBy"
  end
  stationData[:bound] = bound
  
  # カーブデータ取得
  curves = Hash.new
  file_body.gsub!(/\<gml\:Curve gml\:id\=\"(.+?)\"\>.+?\<gml\:posList\>(.+?)\<\/gml\:posList\>.+?\<\/gml\:Curve\>/m) do |curve|
    key = $1
    poslists = $2.split("\n")
    posArray = Array.new
    poslists.each do|pos|
      if pos =~ /(-*[0-9\.]+?)\s+(-*[0-9\.]+?)$/
        pos = Hash.new
        pos[:lat] = $2
        pos[:lng] = $1
        posArray << pos
      end
    end
    curves[key] = posArray
    "# #{key}"
  end
  # puts "CURVES:\n"+curves.to_s
  stationData[:curves] = curves
  # レールデータ取得
  rail_roads = Hash.new
  file_body.gsub!(/\<ksj\:RailroadSection gml\:id=\"(.+?)\"\>(.+?)\<\/ksj\:RailroadSection\>/m) do |rail_road|
    key = $1
    body = $2
    hash = Hash.new
    if body =~ /\<ksj\:location xlink\:href\=\"\#(.+?)\"\/\>/
      hash[:location] = $1
    end
    if body =~ /\<ksj\:railwayType\>(\d+?)\<\/ksj\:railwayType\>/
      hash[:railway_type] = $1
    end
    if body =~ /\<ksj\:serviceProviderType\>(\d+)\<\/ksj\:serviceProviderType\>/
      hash[:service_provider_type] = $1
    end
    if body =~ /\<ksj\:railwayLineName>(.+?)\<\/ksj\:railwayLineName\>/
      hash[:railway_line_name] = $1
    end
    if body =~ /\<ksj\:operationCompany\>(.+?)\<\/ksj\:operationCompany\>/
      hash[:operation_company] = $1
    end
    if body =~ /\<ksj\:station xlink\:href\=\"\#(.+?)\"\/\>/
      hash[:station] = $1
    end
    rail_roads[key] = hash
    "# #{key}"
  end
  # puts "RAIL_ROADS:\n" + rail_roads.to_s
  stationData[:rail_roads] = rail_roads

  # 駅データ取得
  stations = Hash.new
  file_body.gsub!(/\<ksj\:Station gml\:id\=\"(.+?)\"\>(.+?)\<\/ksj\:Station\>/m) do |station|
    key = $1
    body = $2
    hash = Hash.new
    if body =~ /\<ksj\:location xlink\:href\=\"\#(.+?)\"\/\>/
      hash[:location] = $1
    end
    if body =~ /\<ksj\:railwayType\>(\d+?)\<\/ksj\:railwayType\>/
      hash[:railway_type] = $1
    end
    if body =~ /\<ksj\:serviceProviderType\>(\d+?)\<\/ksj\:serviceProviderType\>/
      hash[:service_provider_type] = $1
    end
    if body =~ /\<ksj\:railwayLineName\>(.+?)\<\/ksj\:railwayLineName\>/
      hash[:railway_line_name] = $1
    end
    if body =~ /\<ksj\:operationCompany\>(.+?)\<\/ksj\:operationCompany\>/
      hash[:operation_company] = $1
    end
    if body =~ /\<ksj\:stationName\>(.+?)\<\/ksj\:stationName\>/
      hash[:station_name] = $1
    end
    if body =~ /\<ksj\:railroadSection xlink\:href\=\"\#(.+?)\"\/\>/
      hash[:railroad_section] = $1
    end
    stations[key] = hash
    "# #{key}"
  end
  # puts "STATIONS:\n" + stations.to_s.encode('cp932')
  stationData[:stations] = stations
  out_array = create_kml(stationData)
  File.write argv[1], out_array.join("\n")
  
  
  # puts file_body.encode('cp932') # ここに < > が発生してたら取りこぼし。。。
rescue => exception
  puts "Exception:#{exception.message}"
  puts $@
ensure
end
puts 'complate.'
