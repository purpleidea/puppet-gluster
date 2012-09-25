module Puppet

  newtype(:gluster_volume) do

    @doc = "Manage GlusterFS volumes"

    ensurable

    newparam(:name) do
      isnamevar
    end

    newproperty(:bricks, :array_matching => :all) do
      desc "List of bricks for this volume"
      defaultto []
    end

    newparam(:replica) do
      desc "Replica count, default 1"
      newvalues(/^[1-9]$/)
      defaultto 1
    end

    newproperty(:status) do
      desc "Status of the volume"
      defaultto :started
      newvalues(:started,:stopped)
    end

    validate do

      # Test if there are defined some bricks... can't this be configured in the newproperty block... setting as required ?
      if ( self[:bricks].length == 0 )
        self.fail("Amount of bricks should not be 0")
      end

      if ( self[:bricks].length.modulo(self[:replica].to_i) != 0 )
        self.fail("Amount of bricks should be a multiple or equal to the replica count")
      end
    end

  end

end
