require 'mechanize' # you'll need Mechanize installed (gem install mechanize)

@agent = Mechanize.new
@visited_links = Array.new
@random = false
@symbols = Symbol.all_symbols
# Possible input: fuzz [discover | test] url OPTIONS
def args
  options = {}
  options[:type] = ARGV[0]
  options[:url] = ARGV[1]

  if (ARGV[2].include? "--custom-auth") # [--custom-auth | --common-words | --vectors | --sensitive | --random | --slow]
    options[:auth] = 'dvwa'
  elsif (ARGV[2].include? "--common-words")
    @words = true
    arg = ARGV[2].split("=")
    options[:words] = arg[1]
  end

  if (ARGV[3])
    arg = ARGV[3].split("=")
    if (ARGV[3].include? "--common-words")
      @words = true
      options[:words] = arg[1]
    elsif (ARGV[3].include? "--vectors")
      @vectors = true
      options[:vectors] = arg[1]
    end
  end

  if (ARGV[4])
    arg = ARGV[4].split("=")
    if (ARGV[4].include? "--vectors")
      @vectors = true
      options[:vectors] = arg[1]
    elsif (ARGV[4].include? "--sensitive")
      @sensitive = true
      options[:sensitive] = arg[1]
    end
  end

  if (ARGV[5])
    arg = ARGV[5].split("=")
    if (ARGV[5].include? "--sensitive")
      @sensitive = true
      options[:sensitive] = arg[1]
    elsif (ARGV[5].include? "--random")
      if (arg[1] == "true")
        @random = true
      end
      options[:random] = arg[1]
    elsif (ARGV[5].include? "--slow")
      @slow = true
      options[:slow] = arg[1]
    end
  end

  if (ARGV[6])
    arg = ARGV[6].split("=")
    if (ARGV[6].include? "--random")
      if (arg[1] == "true")
        @random = true
      end
      options[:random] = arg[1]
    elsif (ARGV[6].include? "--slow")
      @slow = true
      options[:slow] = arg[1]
    end
  end

  if (ARGV[7])
    arg = ARGV[7].split("=")
    if (ARGV[7].include? "--slow")
      @slow = true
      options[:slow] = arg[1]
    end
  end

  options
end

@url = args[:url]
puts "Visiting #{@url}"
@page = @agent.get(@url)
form = @page.forms.first

puts args

def parse_file(path) # Function to parse text files & return list of words
  lines = []
  f = File.open(path, 'r')
  f.each_line do |line| # Go through each line, remove whitespace, append line
    line.delete!("\n")
    lines.push(line)
  end
  lines
end

# if args[:auth] == 'dvwa' # login and change security level
form['username'] = 'admin'
form['password'] = 'password'
form.click_button()
@page = form.submit
puts "Login successful. Changing Security..."
@page = @agent.current_page.uri.host
@page = @agent.get('security.php')
@page.forms.first.field_with(:name => 'security').options[0].select
@page = @page.forms.first.click_button
puts "Security set to low."
# end

def guess_links # Function to loop through links and try to find valid new links
  puts "\n-------------------------------------------\nSuccessfully guessed links:\n-------------------------------------------"
  @successful_guesses = []
  @visited_links.each do |link| # For each visited link, try words from common-words
    if (!(link.include? ".php") && !(link.include? ".html"))
      guess = ""
      parsed_words = parse_file(args[:words])
      parsed_words.each do |line|
        guess = link + line
        begin
          @agent.get(guess) do |page| # Loop through and append guess
            puts guess
            @successful_guesses.push(guess)
          end
        rescue Mechanize::ResponseCodeError, Net::HTTPNotFound # This guess does not work!
          # puts "404!- " + "#{guess}"
          next
        end
      end
    end
  end
  @visited_links = @visited_links | @successful_guesses
  puts "\n-------------------------------------------\nDisplay inputs for pages:\n-------------------------------------------"
  @page = @agent.get(@url)
  form = @page.forms.first
  form['username'] = 'admin'
  form['password'] = 'password'
  form.click_button()
  @page = form.submit # Logged in
  @visited_links.each do |link| # Loop through links, display inputs
    @page = @agent.get(link)
    form = @page.forms.first
    if (form == nil)
    else
      puts "#{@page.title}:\n    Keys:#{form.keys}\n    Values:#{form.values}\n\n"
    end
  end
  puts "Cookies: \n"
  @agent.cookies.each do |cookie|
    puts "    #{cookie.to_s}"
  end
end

def discover_links(site) # Loop through links on page. If not visited earlier, display link
  @agent.get(site).links.each do |link|
      if (!(@visited_links.include? link.click.uri.to_s))
        puts "Link '#{link.to_s}' found at '#{link.click.uri}'"
        @visited_links.push(link.click.uri.to_s)
      end
  end
end

# Gather all links, try guessing new ones
puts "\nDiscovering...\n\n-------------------------------------------\nInitially discovered links:\n-------------------------------------------"
discover_links(@url)
if (@words)
  guess_links
end
if (args[:type] == 'test') # Gathered all links, begin testing
  puts "\n-------------------------------------------\nTest mode selected...\n-------------------------------------------"
  @page = @agent.get(@url)

  if (@slow) # Define the number of milliseconds considered as a slow response
    @agent.read_timeout = args[:slow].to_i
    @agent.open_timeout = args[:slow].to_i
  else # Default value is 500ms
    @agent.read_timeout = 500
    @agent.open_timeout = 500
  end
  puts "Pages will timeout if they surpass #{@agent.read_timeout} milliseconds."

  if (@vectors && @sensitive)
    # Scramble the pages if random
    puts "Randomness set to #{@random}."
    if (@random)
      puts "Randomizing links..."
      @visited_links.shuffle!
    end

    puts "Testing with vectors now..."
    @visited_links.each do |link| # Loop through each discovered link
      @agent.get(link)
      @page = @agent.current_page
      successful_exploits = Array.new
      unsanitized = Array.new # List of unsanitized inputs

      @page.forms.each do |form| # Loop through each form
        if (@random) # Shuffle the page's inputs
          form.fields.shuffle!
        end

        form.fields.each do |input| # Loop through each field
          vectors = parse_file(args[:vectors])
          vectors.each do |vector| # Loop through and try each vector
            form[input.name] = vector

            begin
              submit_page = form.click_button() # Test the vector
              sensitive = parse_file(args[:sensitive])
              sensitive.each do |sensitive|
                if submit_page.body.include?(sensitive)
                  successful_exploits.push("    Sensitive information '#{sensitive}' exposed using vector #{vector} on input #{input.name}")
                end
              end
              if (submit_page.body.include?("You have an error in your SQL syntax"))
                successful_exploits.push("    SQL syntax error using vector #{vector} on input #{input.name}")
              end
              # Catch Unsanitized Inputs
              if (@symbols.include?(vector.to_sym) && submit_page.body.include?(vector) && !unsanitized.include?(vector))
                unsanitized.push(vector)
              end
            # Catch timeouts, HTTP responses
            rescue Exception, Timeout::Error, Net::ReadTimeout, Mechanize::ResponseCodeError => e
              successful_exploits.push("    The page has encountered an error: #{e.message}")
            end
          end
        end
      end

      if (successful_exploits.empty?) # Skip of there aren't any exploits
      else # Display exploits
        puts "\n#{@page.title} encountered exploits:\n"
        successful_exploits.each do |exploit|
          puts exploit
        end
        if (unsanitized.size > 0)
          puts "    Number of Unsanitized Inputs: #{unsanitized.size}, #{unsanitized.to_s}"
        end
      end
    end
  end

end
