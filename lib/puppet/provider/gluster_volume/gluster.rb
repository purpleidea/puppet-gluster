Puppet::Type.type(:gluster_volume).provide(:gluster) do

  commands :gluster => '/usr/sbin/gluster'

  def exists?

    if ! gluster('volume','list').match('\b'+@resource[:name]+'\b').nil?
      @@info = load_volume_info(@resource[:name])
      return true
    else
      return false
    end

  end

  def create

    command = ['--mode=script','volume', 'create', @resource[:name]]

    if ( @resource[:replica].to_i > 1 )
      command += ['replica', @resource[:replica]]
    end

    command += @resource[:bricks]

    gluster(command)

    @@info = load_volume_info(@resource[:name])

    unless self.status == @resource.should(:status)
      self.status=(@resource.should(:status))
    end

    # Give gluster some time to start the nfs server
    sleep(5)

  end

  def destroy

    if self.status == 'started'
      self.status=(:stopped)
    end
    gluster('--mode=script','volume','delete',@resource[:name])

  end

  #
  # Getters and Setters
  #

  def bricks
    @@info['bricks']
  end

  def bricks=(value)

    # Add bricks
    tb_add = @resource[:bricks] - self.bricks
    if ( ! tb_add.empty? )
      if ( @resource[:replica].to_i > 1 )
        gluster('volume','add-brick',@resource[:name],'replica',@resource[:replica],tb_add)
      else
        gluster('volume','add-brick',@resource[:name],tb_add)
      end
    end

    # Remove bricks
    tb_del = self.bricks - @resource[:bricks]
    if ( ! tb_del.empty? )
      gluster('--mode=script','volume','remove-brick',@resource[:name],'replica',@resource[:replica],tb_del)
    end

  end

  def status
    @@info['status']
  end

  def status=(value)
    if ( value == :started )
      gluster('volume','start',@resource[:name])
    elsif ( value == :stopped )
      gluster('--mode=script','volume','stop',@resource[:name])
    end
  end

  #
  # Helper Functions
  #

  def load_volume_info(volumename)
    info = Hash.new

    gluster('volume','info',volumename).split("\n").each do |line|
    
      if (line =~ /^Status: (.*)$/)
        info['status'] = $1.downcase
        if ( info['status'] == 'created' )
          info['status'] = 'stopped'
        end
      elsif (line =~ /^Brick(\d+): (.*)$/)
        if info['bricks'].nil?
          info['bricks'] = Array.new
        end
        info['bricks'][$1.to_i - 1] = $2
      end

    end

    return info
  end

end
