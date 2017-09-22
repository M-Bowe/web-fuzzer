Installation
* Ensure Ruby is installed and the gem Mechanize is added (gem install mechanize)
* Pull the master branch of this repository
* Launch Git Bash inside the repository, please read important note before executing commands.

Part 0: --custom-auth:

An example of properly using --custom-auth: `ruby fuzzer.rb test http://127.0.0.1/dvwa/index.php --custom-auth=dvwa`


Part 1: discover:

An example of properly using the discover command: `ruby fuzzer.rb discover http://localhost/dvwa --custom-auth=dvwa --common-words=/words.txt`


Part 2: test:

An example of properly using the test command: `ruby fuzzer.rb test http://localhost/dvwa --custom-auth=dvwa --common-words=/words.txt --vectors=/vectors.txt --sensitive=my_sensitive_data_file.txt --random=true --slow=100`
