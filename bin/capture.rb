require 'byebug'
require "csv"
require 'json'
require 'RMagick'
require 'selenium-webdriver'
require 'uri'

def setup_driver(is_pc_mode)
  options = Selenium::WebDriver::Options.chrome
  options.add_argument('--headless')
  options.add_argument('--disable-gpu')

  if is_pc_mode
    options.add_argument('--window-size=1280,800')
  else
    options.add_argument('--window-size=375,667')
  end

  puts "Setting up the driver..."
  Selenium::WebDriver.for(:chrome, options: options)
end

def target_urls
  puts "Reading URLs from CSV file..."
  puts ''

  csv = CSV.read('config/urls.csv')
  csv.flatten
end

def get_domain(url)
  uri = URI.parse(url)
  scheme = uri.scheme
  host = uri.host
  port = uri.port
  "#{scheme}://#{host}:#{port}/"
end

def load_cookies(url, driver)
  puts "  Loading cookies for: #{url}"
  domain = get_domain(url)
  driver.navigate.to(domain)

  cookies = JSON.parse(File.read('config/cookies.json'))
  cookies.select! { |cookie| domain.include?(cookie['domain']) }
  cookies.each do |cookie|
    data = {
      name: cookie['name'],
      value: cookie['value'],
      path: cookie['path'],
      domain: cookie['domain'],
      secure: cookie['secure'],
      http_only: cookie['httpOnly']
    }
    data[:expires] = Time.at(cookie['expirationDate']) if cookie['expirationDate']
    driver.manage.add_cookie(data)
  end

  puts "  Cookies loaded and browser refreshed."
  driver.navigate.refresh
end

def add_pathstamp(image_path, url)
  puts "  Annotating image with URL stamp..."
  image = Magick::Image.read(image_path).first
  draw = Magick::Draw.new

  draw.annotate(image, 0, 0, 10, 10, url) do |options|
    options.pointsize = 32
    options.fill = 'blue'
    options.stroke = 'white'
    options.gravity = Magick::NorthWestGravity
  end
  image.write(image_path)
end

def save_full_screenshot(driver, is_pc_mode, url)
  puts "  Capturing full screenshot for: #{url}"
  timestamp = Time.now.strftime('%Y-%m-%d %H.%M.%S')
  filename = "スクリーンショット #{timestamp}.png"
  image_path = "screenshots/#{filename}"

  driver.get(url)
  sleep(3)

  total_width = driver.execute_script("return document.body.offsetWidth")
  total_height = driver.execute_script("return document.body.scrollHeight")
  driver.manage.window.resize_to(total_width, total_height)

  driver.save_screenshot(image_path)
  add_pathstamp(image_path, url)
  puts "  Screenshot saved: #{image_path}"
  puts ''
  
  if is_pc_mode
    driver.manage.window.resize_to(1280, 800)
  else
    driver.manage.window.resize_to(375, 667)
  end
end

def capture_screenshot
  puts "Enter 'pc' for PC or 'sp' for smartphone captures. [pc/sp]"
  is_pc_mode = gets.chomp.downcase == 'pc'

  if is_pc_mode
    puts 'Capturing in PC size...'
    puts ''
  else
    puts 'Capturing in SP size...'
    puts ''
  end

  
  driver = setup_driver(is_pc_mode)
  urls = target_urls

  urls.each_with_index do |url, index|
    puts "  Processing #{index + 1}/#{urls.length}: #{url}"
    begin
      load_cookies(url, driver)
      save_full_screenshot(driver, is_pc_mode, url)
    rescue => e
      puts "  [Error] can't capture on #{url}  error: #{e}"
      next
    end
  end
    
  driver.quit
  puts "All screen captures are completed."
end

capture_screenshot
