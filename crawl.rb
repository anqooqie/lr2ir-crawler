#!/usr/bin/env ruby

unless ARGV.length == 2
    STDERR.puts "usage: RUBYLIB=lib bundle exec ruby #{$0} <sqlite3 database> <URI of difficulty table>"
    exit!
end

require 'logger'
require 'models'

ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = 1

ActiveRecord::Base.establish_connection(
    adapter: "sqlite3",
    database: ARGV[0]
)

difficulty_table = DifficultyTable.find_by_uri(ARGV[1]) || DifficultyTable.load_from_uri(ARGV[1])
difficulty_table.save

bms_file_count = difficulty_table.levels.collect {|level| level.bms_files.count}.inject(0, :+)
bms_file_total_index = 0
difficulty_table.levels.count.times do |level_index|
    level = difficulty_table.levels.order(:level_order).limit(1).offset(level_index).first
    level.bms_files.count.times do |bms_file_index|
        bms_file = level.bms_files.order(:id).limit(1).offset(bms_file_index).first
        if bms_file.scores.count == 0
            bms_file.load_from_ir
            ActiveRecord::Base.logger.info("#{difficulty_table.symbol}#{level.name} #{bms_file.title} [#{bms_file_total_index + 1}/#{bms_file_count}]")
            bms_file.save
        else
            ActiveRecord::Base.logger.info("#{difficulty_table.symbol}#{level.name} #{bms_file.title} [#{bms_file_total_index + 1}/#{bms_file_count}] (skipped)")
        end
        bms_file_total_index += 1
    end
end
