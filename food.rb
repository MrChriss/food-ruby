#! /usr/bin/env nix-shell
#! nix-shell -i ruby -p "ruby_3_1.withPackages (ps: with ps; [nokogiri])"

# frozen_string_literal: true

require 'nokogiri'
require 'open-uri'
require 'optparse'
require 'delegate'

# Parses Mrlacnik's menu
class Mrlacnik
  FOOD_URL = 'https://www.kasca-mrlacnik.jedilnilist.si/stran/malica/'
  MENU_XPATH = '/html/body/main/div/div/div/div'
  DATE_XPATH = '/html/body/main/div/div/div/div/h6[2]/span'

  # input:
  #   Nokogiri HTML document
  # returns:
  #   [['dish name', '7,00€'], ['other dish name', '6,00€']]
  def menu # rubocop:disable Metrics/MethodLength
    @menu ||= doc
              .xpath(MENU_XPATH)
              .search('h6')
              .map(&:text)                              # extract text from the elements above
              .map { _1.gsub(/[[:space:]]+/, ' ') }     # convert 'weird' whitespace characters, to a single space
              .reject(&:empty?)                         # remove empty elements
              .slice(1..)                               # drop first element (which is the date, and not a menu item)
              .flat_map { _1.split('€') }               # handle first two menu items which are one string due to bad markup by the website maintainers
              .map { _1.strip.<<('€') }                 # remove whitespace and append '€', to get consistent price format at the end of each menu item
              .slice(..-2)                              # last element is not needed
              .map { _1.gsub(/\([A-Za-z,\.]+\)/, ' ') } # remove information about allergenes
              .map { _1.split(/\s(?=\d)/) }             # split price and dish name, so that they can be presented better
              .map { [_1, _2.gsub(/\s*/, '')] }         # remove whitespace from price
  end

  # input:
  #   Nokogiri HTML document
  # returns:
  #   "Petek, 29.10.2021"
  def date
    @date ||= doc
              .xpath(DATE_XPATH)
              .text
              .gsub(/[[:space:]]+/, ' ') # convert 'weird' whitespace characters, to a single space
  end

  def doc
    @doc ||= Nokogiri::HTML(URI.parse(FOOD_URL).open)
  end
end

# Prints the menu to the terminal
class Presenter < SimpleDelegator
  PRICE_SPACE_PADDING = 2

  def call
    ArgParser.call.short ? present_short : present_long
  end

  private

  # input:
  #   menu: [['dish name', '7,00€'], ['other dish name', '6,00€']]
  #   date: "Petek, 29.10.2021"
  # returns:
  #   input
  # side effects:
  #   prints date and menu items to screen
  def present_short
    present_date
    menu.map(&:first).each { puts "- #{_1} \n\n" }
  end

  # input:
  #   menu: [['dish name', '7,00€'], ['other dish name', '6,00€']]
  #   date: "Petek, 29.10.2021"
  # returns:
  #   input
  # side effects:
  #   prints date and menu items to screen
  def present_long
    present_date

    menu.map { _1.ljust(menu_entry_justification) + _2 }.each do
      puts _1
      puts '-' * _1.size
    end
  end

  # input:
  #   menu: [['dish name', '7,00€'], ['other dish name', '6,00€']]
  # returns:
  #   int
  def menu_entry_justification
    PRICE_SPACE_PADDING + menu.flatten.max_by(&:size).size
  end

  def present_date
    puts date
    puts '=' * date.size
  end
end

# Parses CLI flags
class ArgParser
  Options = Struct.new(:short)

  def self.call
    new.call
  end

  def call
    parse(ARGV)
  end

  private

  def parse(options) # rubocop:disable Metrics/MethodLength
    args = Options.new(true)

    opt_parser = OptionParser.new do |opts|
      opts.banner = 'Usage: food [options]'
      opts.on('-s', '--short', 'Prints short summary of todays menu') { args.short = true }
      opts.on('-l', '--long', 'Prints formatted summary of todays menu, prices included') { args.short = false }
      opts.on('-h', '--help', 'Prints this help') do
        puts opts
        exit
      end
    end

    opt_parser.parse!(options)
    args
  end
end

Presenter.new(Mrlacnik.new).call
