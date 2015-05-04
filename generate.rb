require 'pty'

output = ""
read_io, write_io, pid = nil

dir = File.expand_path("examples.sh")

# spawn the process in a pseudo terminal so colors out outputted
read_io, write_io, pid = PTY.spawn("./examples.sh")

write_io.close

loop do
  fds, = IO.select([read_io], nil, nil, 5)
  if fds
    # should have some data to read
    begin
      chunk = read_io.read_nonblock(10240)
      if block_given?
        yield chunk
      end
      output += chunk
    rescue Errno::EAGAIN, Errno::EWOULDBLOCK
      # do select again
    rescue EOFError, Errno::EIO # EOFError from OSX, EIO is raised by ubuntu
      break
    end
  end
  # if fds are empty, timeout expired - run another iteration
end

read_io.close
Process.waitpid(pid)

examples = output.split("---").map do |example|
  klass, *lines = example.chomp.strip.split("\r\n")
  example = lines.join("\r\n")

  rendered = IO.popen(['terminal-to-html'], 'r+') do |p|
    p.write(example)
    p.close_write
    p.read
  end

  %(<section class="example #{klass}">
      <div class="code before">
        <pre>#{example.chomp.strip}</pre>
      </div>
      <div class="code after">
        <pre>#{rendered.chomp.strip}</pre>
      </div>
    </section>)
end.join("\n")

template = File.read("template.html")

File.open("index.html", "w") do |file|
  file.write("<!--  DO NOT EDIT THIS FILE. GENERATED -->\n")
  file.write(template.gsub(/<!-- EXAMPLES HERE -->/, examples))
end
