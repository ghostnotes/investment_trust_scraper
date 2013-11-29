require 'open-uri'
require 'rubygems'
require 'nokogiri'

class InvestmentTrust
  PARAM_NAME_ISIN_CODE = 'isinCd'

  #国内株式 投信
  LARGE_CATEGORY_CODE_DOMESTIC_STOCK = '003'
  #内外株式 投信
  LARGE_CATEGORY_CODE_INSIDE_OUTSIDE_STOCK = '004'
  #海外株式 投信
  LARGE_CATEGORY_CODE_OVERSEAS_STOCK = '005'
  #国内債券 投信
  LARGE_CATEGORY_CODE_DOMESTIC_BOND = '006'
  #内外債券 投信
  LARGE_CATEGORY_CODE_INSIDE_OUTSIDE_BOND = '007'
  #海外債券 投信
  LARGE_CATEGORY_CODE_OVERSEAS_BOND = '008'
  #不動産 投信
  LARGE_CATEGORY_CODE_REAL_ESTATE = '009'
  #複合資産 投信
  LARGE_CATEGORY_CODE_COMPLEX = '010'
  #その他 投信
  LARGE_CATEGORY_CODE_OTHERS = '011'
  #ETF
  LARGE_CATEGORY_CODE_ETF = '001'
  #日々決算型
  LARGE_CATEGORY_CODE_HIBI_KESSAN = '002'

  LARGE_CATEGORY_CODES = {
    LARGE_CATEGORY_CODE_DOMESTIC_STOCK => 4,
    LARGE_CATEGORY_CODE_INSIDE_OUTSIDE_STOCK => 10,
    LARGE_CATEGORY_CODE_OVERSEAS_STOCK => 9,
    LARGE_CATEGORY_CODE_DOMESTIC_BOND => 5,
    LARGE_CATEGORY_CODE_INSIDE_OUTSIDE_BOND => 10,
    LARGE_CATEGORY_CODE_OVERSEAS_BOND => 9,
    LARGE_CATEGORY_CODE_REAL_ESTATE => 3,
    LARGE_CATEGORY_CODE_COMPLEX => 3,
    LARGE_CATEGORY_CODE_OTHERS => 4,
    LARGE_CATEGORY_CODE_ETF => 4,
    LARGE_CATEGORY_CODE_HIBI_KESSAN => 5,
  }

  FRONT_CSV_FILE_NAMES = {
    LARGE_CATEGORY_CODE_DOMESTIC_STOCK => 'domestic_stock_',
    LARGE_CATEGORY_CODE_INSIDE_OUTSIDE_STOCK => 'inside_outside_stock_',
    LARGE_CATEGORY_CODE_OVERSEAS_STOCK => 'overseas_stock_',
    LARGE_CATEGORY_CODE_DOMESTIC_BOND => 'domestic_bond_',
    LARGE_CATEGORY_CODE_INSIDE_OUTSIDE_BOND => 'inside_outside_bond_',
    LARGE_CATEGORY_CODE_OVERSEAS_BOND => 'overseas_bond_',
    LARGE_CATEGORY_CODE_REAL_ESTATE => 'real_estate_',
    LARGE_CATEGORY_CODE_COMPLEX => 'complex_',
    LARGE_CATEGORY_CODE_OTHERS => 'others_',
    LARGE_CATEGORY_CODE_ETF => 'etf_',
    LARGE_CATEGORY_CODE_HIBI_KESSAN => 'hibi_kessan_',
  }

  def scrape_investment_trust_names(large_category_code)
    make_investment_trust_csv(large_category_code)
  end

  private

  def generate_csv_file_name(large_category_code)
    today = Time.now
    front_csv_file_name = FRONT_CSV_FILE_NAMES[large_category_code]
    front_csv_file_name + today.strftime("%Y%m%d_%H%M%S_#{today.usec.to_s[0, 3]}") + '.csv'
  end

  def make_investment_trust_csv(large_category_code)
    infos = request_investment_trust_infos(large_category_code)

    csv_file_name = generate_csv_file_name(large_category_code)
    File.open("../csv/#{csv_file_name}", 'a'){|f|
      infos.each do |line|
        f.write line
      end
    }
  end

  def request_investment_trust_infos(large_category_code)
    investment_trust_infos = []

    category_size = LARGE_CATEGORY_CODES[large_category_code]
    category_size.times do |i|
      tmp_category_code = i + 1
      raise StandardError, "Unexpected size > [#{tmp_category_code}]" if tmp_category_code >= 50

      if tmp_category_code < 10
        category_code = '00' + tmp_category_code.to_s
      else
        category_code = '0' + tmp_category_code.to_s
      end

      page_no = 1
      has_investment_trust_data = true

      while has_investment_trust_data do
        url = "http://tskl.toushin.or.jp/FdsWeb/view/FDST010001.seam?largeCategoryCd=#{large_category_code}&categoryCd=#{category_code}&pyyClss=2&PageNo=#{page_no}"
        puts "Loading LargeCategoryCODE: [ #{large_category_code} ] CategoryCODE: [ #{category_code} ] ..."
        puts " -> URL: #{url}"
        puts "  Page [#{page_no}]"

        doc = Nokogiri::HTML(open(url))
        items = doc.xpath('//div[@class = "fund01"]/table[@class = "mt12"]')
        item_length = items.length
        if item_length <= 0
          has_investment_trust_data = false
          puts "finished to scrape. Last page number: #{page_no}"
          break
        end

        items.each_with_index do |item, i|
          puts "    Item [#{i}] / #{item_length}"
          a_tag = item.xpath('.//td[@class = "pdl10"]/a').first
          name = a_tag.xpath('.//strong').text.strip
          item_url = a_tag.attr('href').strip
          isin_code = get_param_value(PARAM_NAME_ISIN_CODE, item_url)
          started_date = item.xpath('.//td[@width = "131"]').text.strip

          investment_trust_infos << "#{name},#{isin_code},#{started_date}\n"
        end

        page_no += 1
      end
    end

    investment_trust_infos
  end

  def get_param_value(parameter_name, url)
    unless url.include?(parameter_name)
      return nil
    end

    params = url.split('?')
    params = params[1].split('&')

    param_value = nil
    params_length = params.length
    params_length.times do |i|
      if params[i].start_with?(parameter_name)
        param_value = params[i].split('=')[1].strip
        break
      end
    end

    param_value
  end
end
