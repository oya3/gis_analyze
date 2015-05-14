# coding: utf-8
require 'optparse' # オプション解析
require 'pry'

Encoding.default_external = 'utf-8'
Encoding.default_internal = 'utf-8'

# http://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N02.html
# 「鉄道区分コード」 == railwayType
# 11	普通鉄道JR	
# 12	普通鉄道	
# 13	鋼索鉄道	車両にロープを緊結して山上の巻上機により巻上げて運転するのもであって，一般にケーブルカーと称されるものである。
# 14	懸垂式鉄道	都市交通として利用されるモノレールの構造上の分類であって，車両の斜体部分が軌道桁より垂れ下がっているものである。
# 15	跨座式鉄道	モノレールの分類で，車両の車体部分が軌道桁より上方にあってこれをまたぐ形ものである。
# 16	案内軌条式鉄道	軌道に車両の鉛直荷重を受ける走行路と車両の走行向を誘導する案内軌条を有し，操向装置として案内輪を有するものである。
# 17	無軌条鉄道	レールを設けないで，普通の道路を架空電線に接して走る電車で一般にはトロリーバスと称される。
# 21	軌道	道路に敷設されたレールを進行させるもの。道路交通の補助機関として一般に供されるもので，軌道法の適用を受けるものである。
# 22	懸垂式モノレール	都市交通として利用されるモノレールの構造上の分類であって，車両の斜体部分が軌道桁より垂れ下がっているものである。
# 23	跨座式モノレール	モノレールの分類で，車両の車体部分が軌道桁より上方にあってこれをまたぐ形ものである。
# 24	案内軌条式	軌道に車両の鉛直荷重を受ける走行路と車両の走行向を誘導する案内軌条を有し，操向装置として案内輪を有するものである。
# 25	浮上式	

# 「事業者種別コード」== serviceProviderType
# 1	JRの新幹線
# 2	JR在来線
# 3	公営鉄道
# 4	民営鉄道
# 5	第三セクター


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


def get_xml_bound(file_body)
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
  return bound
end

def get_xml_curves(file_body)
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
  return curves
end

# レール
# <ksj:location xlink:href="#cv_rss17298"/>
# <ksj:railwayType>11</ksj:railwayType>
# <ksj:serviceProviderType>2</ksj:serviceProviderType>
# <ksj:railwayLineName>八戸線</ksj:railwayLineName>
# <ksj:operationCompany>東日本旅客鉄道</ksj:operationCompany>

# <ksj:station xlink:href="#eb03_8090"/>

# 駅
# <ksj:location xlink:href="#cv_stn3081"/>
# <ksj:railwayType>12</ksj:railwayType>
# <ksj:serviceProviderType>4</ksj:serviceProviderType>
# <ksj:railwayLineName>多摩線</ksj:railwayLineName>
# <ksj:operationCompany>小田急電鉄</ksj:operationCompany>

# <ksj:stationName>新百合ヶ丘</ksj:stationName>
# <ksj:railroadSection xlink:href="#eb02_6211"/>
def get_xml_commons(file_body,ksj_name)
  commons = Hash.new
  file_body.gsub!(/\<ksj\:#{ksj_name} gml\:id=\"(.+?)\"\>(.+?)\<\/ksj\:#{ksj_name}\>/m) do |rail_road|
    key = $1
    body = $2
    hash = Hash.new
    # レール＆駅 共通エリア
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
    # レール専用エリア
    if body =~ /\<ksj\:station xlink\:href\=\"\#(.+?)\"\/\>/
      hash[:station] = $1
    end
    
    # 駅専用エリア
    if body =~ /\<ksj\:stationName\>(.+?)\<\/ksj\:stationName\>/
      hash[:station_name] = $1
    end
    if body =~ /\<ksj\:railroadSection xlink\:href\=\"\#(.+?)\"\/\>/
      hash[:railroad_section] = $1
    end

    commons[key] = hash
    "# #{key}"
  end
  return commons
end


puts "get_station_info version.0.2015.05.12.0945"
inparam = Hash.new # 入力情報保持用

# オプション解析用パーサー生成
opt = OptionParser.new
opt.on('-d', '--debug') {|val| inparam[:debug] = true }

argv = opt.parse(ARGV)
if argv.length != 2 then
    puts "usage gis_analyze <xml path> <outfile path(kml)>"
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
  # bound = Hash.new
  # file_body.gsub!(/\<gml\:boundedBy\>.+?\<gml\:EnvelopeWithTimePeriod srsName\=\"(.+?)\" frame\=\"(.+?)\"\>(.+?)\<\/gml\:EnvelopeWithTimePeriod\>.+?\<\/gml\:boundedBy\>/m) do
  #   bound[:src_name] = $1
  #   bound[:frame] = $2
  #   body = $3
  #   if body =~ /\<gml\:lowerCorner\>([0-9\.]+?)\s+([0-9\.]+?)\<\/gml\:lowerCorner\>/
  #     pos = { :lat => $1, :lng => $2}
  #     bound[:lower_corner] = pos
  #   end
  #   if body =~ /\<gml\:upperCorner\>([0-9\.]+?)\s+([0-9\.]+?)\<\/gml\:upperCorner\>/
  #     pos = { :lat => $1, :lng => $2}
  #     bound[:upper_corner] = pos
  #   end
  #   if body =~ /\<gml\:beginPosition calendarEraName\=\"(.+?)\"\>(\d+?)\<\/gml\:beginPosition\>/
  #     hash = { :calendar_era_name => $1, :year => $2}
  #     bound[:bigin_position] = hash
  #   end
  #   if body =~ /\<gml\:endPosition indeterminatePosition=\"(.+?)\"\/\>/
  #     hash = { :indeterminate_position => $1 }
  #     bound[:end_position] = hash
  #   end
  #   "# bml:boundedBy"
  # end
  # バウンドデータ取得
  stationData[:bound] = get_xml_bound(file_body)
  
  # カーブデータ取得
  # curves = Hash.new
  # file_body.gsub!(/\<gml\:Curve gml\:id\=\"(.+?)\"\>.+?\<gml\:posList\>(.+?)\<\/gml\:posList\>.+?\<\/gml\:Curve\>/m) do |curve|
  #   key = $1
  #   poslists = $2.split("\n")
  #   posArray = Array.new
  #   poslists.each do|pos|
  #     if pos =~ /(-*[0-9\.]+?)\s+(-*[0-9\.]+?)$/
  #       pos = Hash.new
  #       pos[:lat] = $2
  #       pos[:lng] = $1
  #       posArray << pos
  #     end
  #   end
  #   curves[key] = posArray
  #   "# #{key}"
  # end
  # puts "CURVES:\n"+curves.to_s
  # カーブデータ取得
  stationData[:curves] = get_xml_curves(file_body)
  
  # レールデータ取得
  # rail_roads = Hash.new
  # file_body.gsub!(/\<ksj\:RailroadSection gml\:id=\"(.+?)\"\>(.+?)\<\/ksj\:RailroadSection\>/m) do |rail_road|
  #   key = $1
  #   body = $2
  #   hash = Hash.new
  #   if body =~ /\<ksj\:location xlink\:href\=\"\#(.+?)\"\/\>/
  #     hash[:location] = $1
  #   end
  #   if body =~ /\<ksj\:railwayType\>(\d+?)\<\/ksj\:railwayType\>/
  #     hash[:railway_type] = $1
  #   end
  #   if body =~ /\<ksj\:serviceProviderType\>(\d+)\<\/ksj\:serviceProviderType\>/
  #     hash[:service_provider_type] = $1
  #   end
  #   if body =~ /\<ksj\:railwayLineName>(.+?)\<\/ksj\:railwayLineName\>/
  #     hash[:railway_line_name] = $1
  #   end
  #   if body =~ /\<ksj\:operationCompany\>(.+?)\<\/ksj\:operationCompany\>/
  #     hash[:operation_company] = $1
  #   end
  #   if body =~ /\<ksj\:station xlink\:href\=\"\#(.+?)\"\/\>/
  #     hash[:station] = $1
  #   end
  #   rail_roads[key] = hash
  #   "# #{key}"
  # end
  # puts "RAIL_ROADS:\n" + rail_roads.to_s
  stationData[:rail_roads] = get_xml_commons(file_body,'RailroadSection')

  # 駅データ取得
  # stations = Hash.new
  # file_body.gsub!(/\<ksj\:Station gml\:id\=\"(.+?)\"\>(.+?)\<\/ksj\:Station\>/m) do |station|
  #   key = $1
  #   body = $2
  #   hash = Hash.new
  #   if body =~ /\<ksj\:location xlink\:href\=\"\#(.+?)\"\/\>/
  #     hash[:location] = $1
  #   end
  #   if body =~ /\<ksj\:railwayType\>(\d+?)\<\/ksj\:railwayType\>/
  #     hash[:railway_type] = $1
  #   end
  #   if body =~ /\<ksj\:serviceProviderType\>(\d+?)\<\/ksj\:serviceProviderType\>/
  #     hash[:service_provider_type] = $1
  #   end
  #   if body =~ /\<ksj\:railwayLineName\>(.+?)\<\/ksj\:railwayLineName\>/
  #     hash[:railway_line_name] = $1
  #   end
  #   if body =~ /\<ksj\:operationCompany\>(.+?)\<\/ksj\:operationCompany\>/
  #     hash[:operation_company] = $1
  #   end
  #   if body =~ /\<ksj\:stationName\>(.+?)\<\/ksj\:stationName\>/
  #     hash[:station_name] = $1
  #   end
  #   if body =~ /\<ksj\:railroadSection xlink\:href\=\"\#(.+?)\"\/\>/
  #     hash[:railroad_section] = $1
  #   end
  #   stations[key] = hash
  #   "# #{key}"
  # end
  stationData[:stations] = get_xml_commons(file_body,'Station')

  
  # 取りこぼしデータチェック
  if file_body =~ /[\<\>]/
    puts "取りこぼしている".encode('cp932')
  end
  
  out_array = create_kml(stationData)
  File.write argv[1], out_array.join("\n")

  
  # puts file_body.encode('cp932') # ここに < > が発生してたら取りこぼし。。。
rescue => exception
  puts "Exception:#{exception.message}"
  puts $@
ensure
end
puts 'complate.'
