# -*- coding: utf-8 -*-
require "active_record"
require "nokogiri"
require "net/http"
require "uri"
require "json"

class BmsFile < ActiveRecord::Base
    has_many :level_registrations
    has_many :levels, through: :level_registrations
    has_many :scores
    def total_notes
        scores.select(:total_notes).group_by {|total_notes| total_notes}.max_by{|total_notes, count| count}[0]
    end
    def load_from_ir
        lr2_page = nil
        lr2_page_number = 1
        player_ids = Set.new
        begin
            lr2_page_uri = URI.parse("http://www.dream-pro.info/~lavalse/LR2IR/search.cgi?mode=ranking&page=#{lr2_page_number}&bmsid=#{id}")
            lr2_page = Nokogiri.HTML(
                Net::HTTP.get(lr2_page_uri).force_encoding("CP932").encode("UTF-8")
            )
            lr2_page.xpath("//h3[text()='ランキング']/following-sibling::table/tr/td[@rowspan='2']/..").each do |score_row|
                raise "playerid parse error" unless score_row.xpath("td[2]/a/@href").text =~ /playerid=(\d+)/
                next if player_ids.include?($1.to_i)
                player_ids << $1.to_i
                player = Player.find_or_initialize_by(id: $1.to_i) {|new_player|
                    new_player.name = score_row.xpath("td[2]/a").text
                    new_player.grade = {
                        "-" => 0,
                        "☆01" => 1,
                        "☆02" => 2,
                        "☆03" => 3,
                        "☆04" => 4,
                        "☆05" => 5,
                        "☆06" => 6,
                        "☆07" => 7,
                        "☆08" => 8,
                        "☆09" => 9,
                        "☆10" => 10,
                        "★01" => 11,
                        "★02" => 12,
                        "★03" => 13,
                        "★04" => 14,
                        "★05" => 15,
                        "★06" => 16,
                        "★07" => 17,
                        "★08" => 18,
                        "★09" => 19,
                        "★10" => 20,
                        "★★" => 21,
                        "(^^)" => 22
                    }.fetch(score_row.xpath("td[3]").text.split("/")[0])
                }
                score = scores.build(
                    player_id: player.id,
                    clear: {
                        "FAILED" => "failed",
                        "EASY" => "easy",
                        "CLEAR" => "clear",
                        "HARD" => "hard",
                        "FULLCOMBO" => "full_combo",
                        "★FULLCOMBO" => "perfect"
                    }.fetch(score_row.xpath("td[4]").text),
                    combo: score_row.xpath("td[7]").text.split("/")[0].to_i,
                    total_notes: score_row.xpath("td[7]").text.split("/")[1].to_i,
                    bp: score_row.xpath("td[8]").text.to_i,
                    just_great: score_row.xpath("td[9]").text.to_i,
                    great: score_row.xpath("td[10]").text.to_i,
                    good: score_row.xpath("td[11]").text.to_i,
                    bad: score_row.xpath("td[12]").text.to_i,
                    poor: score_row.xpath('td[13]').text.to_i,
                    gauge_option: {
                        "易" => "easy",
                        "普" => "groove",
                        "難" => "survival",
                        "GA" => "good_attack",
                        "死" => "death",
                        "PA" => "perfect_attack"
                    }.fetch(score_row.xpath("td[14]").text),
                    random_option: {
                        "正" => "normal",
                        "鏡" => "mirror",
                        "乱" => "random",
                        "SR" => "super_random"
                    }.fetch(score_row.xpath("td[15]").text),
                    input: {
                        "KB" => "keyboard",
                        "BM" => "beatmania",
                        "MIDI" => "midi_controller"
                    }.fetch(score_row.xpath("td[16]").text),
                    program: {
                        "LR2" => "lunatic_rave_2",
                        "SBMP" => "simple_bms_player"
                    }.fetch(score_row.xpath("td[17]").text)
                )
                score.player = player
            end
            lr2_page_number_max = Rational(lr2_page.xpath("//h3[text()='総合ステータス']/following-sibling::table[1]/tr[3]/td[1]").text.to_i, 100).ceil
            ActiveRecord::Base.logger.info("#{title} (#{lr2_page_number}/#{lr2_page_number_max})")
            lr2_page_number += 1
        end while lr2_page.xpath("//h3[text()='ランキング']/following-sibling::a[text()='>>']").length > 0
        self
    end
end
class Player < ActiveRecord::Base
    has_many :scores
end
class Score < ActiveRecord::Base
    belongs_to :bms_file
    belongs_to :player
    def ex_score
        just_great * 2 + great
    end
    def dj_level
        rate = Rational(ex_score, total_notes * 2)
        if rate >= Rational(8, 9)
            return "AAA"
        elsif rate >= Rational(7, 9)
            return "AA"
        elsif rate >= Rational(6, 9)
            return "A"
        elsif rate >= Rational(5, 9)
            return "B"
        elsif rate >= Rational(4, 9)
            return "C"
        elsif rate >= Rational(3, 9)
            return "D"
        elsif rate >= Rational(2, 9)
            return "E"
        else
            return "F"
        end
    end
    def dj_point
        clear_mark_bonus = case
        when "failed", "easy"
            0
        when "clear"
            Rational(10, 100)
        when "hard"
            Rational(20, 100)
        when "full_combo", "perfect"
            Rational(30, 100)
        end
        dj_level_bonus = case
        when "F", "E", "D", "C", "B"
            0
        when "A"
            Rational(10, 100)
        when "AA"
            Rational(15, 100)
        when "AAA"
            Rational(20, 100)
        end
        Rational((ex_score * (1 + clear_mark_bonus + dj_level_bonus)).floor, 100)
    end
end
class DifficultyTable < ActiveRecord::Base
    has_many :levels, -> { order(:level_order) }
    def self.load_from_uri(uri)
        difficulty_table_uri = URI.parse(uri)
        header_json_uri = difficulty_table_uri.merge(
            Nokogiri.HTML(
                Net::HTTP.get(difficulty_table_uri).force_encoding("ISO-8859-1").encode("UTF-8")
            ).xpath("//meta[@name='bmstable']/@content").text
        )
        header_json = JSON.parse(
            Net::HTTP.get(header_json_uri).force_encoding("UTF-8")
        )
        data_json_uri = header_json_uri.merge(header_json["data_url"])
        data_json = JSON.parse(
            Net::HTTP.get(data_json_uri).force_encoding("UTF-8")
        )
        level_name_to_order = (
            header_json.has_key?("level_order") ? header_json["level_order"].collect(&:to_s) : data_json.collect {|bms| bms["level"]}.uniq
        ).map.with_index {|name, i| [name, i]}.to_h
        difficulty_table = DifficultyTable.new(
            name: header_json["name"],
            uri: difficulty_table_uri.to_s,
            symbol: header_json["symbol"],
            tag: header_json.has_key?("tag") ? header_json["tag"] : header_json["symbol"]
        )
        difficulty_table.levels = level_name_to_order.map {|name, level_order|
            Level.new(name: name, level_order: level_order + 1)
        }
        data_json.each.with_index do |bms_info, i|
            lr2_page = Nokogiri.HTML(
                Net::HTTP.start("www.dream-pro.info", 80) {|http|
                    http.get("/~lavalse/LR2IR/search.cgi?mode=ranking&bmsmd5=#{bms_info["md5"]}", {
                        "Cookie" => "login=113013,7028110ac59fd2ef511e5665c60788b2,,"
                    })
                }.body.force_encoding("CP932").encode("UTF-8")
            )
            bms_file = BmsFile.find_or_initialize_by(id: lr2_page.xpath("//a[text()='[編集]']/@href").text.split(/=/, -1)[2].to_i) {|new_bms_file|
                new_bms_file.title = lr2_page.xpath("//h1").text
                new_bms_file.play_rank = {
                    "EASY" => "easy",
                    "NORMAL" => "normal",
                    "HARD" => "hard",
                    "VERY HARD" => "very_hard"
                }[lr2_page.xpath("//h3[contains(text(), '情報')]/following-sibling::table[1]/tr[1]/th[text()='判定ランク']/following-sibling::td[1]").text]
            }
            level = difficulty_table.levels[level_name_to_order[bms_info["level"]]]
            level.bms_files << bms_file
            ActiveRecord::Base.logger.info("#{difficulty_table.symbol}#{level.name} #{bms_file.title} (#{i + 1}/#{data_json.size})")
        end
        difficulty_table
    end
end
class Level < ActiveRecord::Base
    belongs_to :difficulty_table
    has_many :level_registrations
    has_many :bms_files, through: :level_registrations
end
class LevelRegistration < ActiveRecord::Base
    belongs_to :bms_file
    belongs_to :level
end
