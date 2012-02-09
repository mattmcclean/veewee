module Veewee
  module Provider
    module Virtualbox
      module BoxCommand

        def add_ide_controller
          #unless => "${vboxcmd} showvminfo '${vname}' | grep 'IDE Controller' "
          command ="#{@vboxcmd} storagectl '#{name}' --name 'IDE Controller' --add ide"
          shell_exec("#{command}")
        end

        def add_sata_controller
          #unless => "${vboxcmd} showvminfo '${vname}' | grep 'SATA Controller' ";
          command ="#{@vboxcmd} storagectl '#{name}' --name 'SATA Controller' --add sata --hostiocache #{definition.hostiocache} --sataportcount 1"
          shell_exec("#{command}")
        end

        def attach_serial_console
          command ="#{@vboxcmd} modifyvm '#{name}' --uart1 0x3F8 4"
          shell_exec("#{command}")
          command ="#{@vboxcmd} modifyvm '#{name}' --uartmode1 file '#{File.join(FileUtils.pwd,name+"-serial-console"+'.log')}'"
          shell_exec("#{command}")
        end

        def add_ssh_nat_mapping

          unless definition.nil?
            #Map SSH Ports
            command="#{@vboxcmd} modifyvm '#{name}' --natpf1 'guestssh,tcp,,#{definition.ssh_host_port},,#{definition.ssh_guest_port}'"
            shell_exec("#{command}")
          end
        end

        def add_shared_folder
          command="#{@vboxcmd} sharedfolder add  '#{name}' --name 'veewee-validation' --hostpath '#{File.expand_path(env.validation_dir)}' --automount"
          shell_exec("#{command}")
        end

        def get_vm_location
          command="#{@vboxcmd}  list  systemproperties"
          shell_results=shell_exec("#{command}",{:mute => true})
          location=shell_results.stdout.split(/\n/).grep(/Default machine/)[0].split(":")[1].strip
          return location
        end


        def suppress_messages
          update_date=Time.now+86400

          extraData = [
            ["Gui/RegistrationData","triesLeft=0"],
            ["Gui/SuppressMessages","confirmInputCapture,remindAboutAutoCapture,remindAboutMouseIntegrationOff,remindAboutMouseIntegrationOn,remindAboutWrongColorDepth"],
            ["GUI/UpdateDate", "1 d, #{update_date.year}-#{update_date.month.to_s.rjust(2,'0')}-#{update_date.day.to_s.rjust(2,'0')}, stable"],
            ["GUI/UpdateCheckCount","60"]
          ]
          extraData.each do |data|
            command="#{@vboxcmd} setextradata global '#{data[0]}' '#{data[1]}'"
            shell_results=shell_exec("#{command}",{:mute => false})
          end

        end


        def create_floppy
          # Todo Check for java
          # Todo check output of commands

          # Check for floppy
          unless definition.floppy_files.nil?
            require 'tmpdir'
            temp_dir=Dir.mktmpdir
            definition.floppy_files.each do |filename|
              full_filename=full_filename=File.join(definition.path,filename)
              FileUtils.cp("#{full_filename}","#{temp_dir}")
            end
            javacode_dir=File.expand_path(File.join(__FILE__,'..','..','..','..','..','..','java'))
            floppy_file=File.join(definition.path,"virtualfloppy.vfd")
            command="java -jar #{javacode_dir}/dir2floppy.jar '#{temp_dir}' '#{floppy_file}'"
            shell_exec("#{command}")
          end
        end

        def create_disk
            env.ui.info "Creating new harddrive of size #{definition.disk_size.to_i} "


            place=get_vm_location
            command ="#{@vboxcmd} createhd --filename '#{File.join(place,name,name+"."+definition.disk_format.downcase)}' --size '#{definition.disk_size.to_i}' --format #{definition.disk_format.downcase}"
            shell_exec("#{command}")

        end

        def attach_disk

          place=get_vm_location
          location=name+"."+definition.disk_format.downcase

          location="#{File.join(place,name,location)}"
          env.ui.info "Attaching disk: #{location}"

          #command => "${vboxcmd} storageattach '${vname}' --storagectl 'SATA Controller' --port 0 --device 0 --type hdd --medium '${vname}.vdi'",
          command ="#{@vboxcmd} storageattach '#{name}' --storagectl 'SATA Controller' --port 0 --device 0 --type hdd --medium '#{location}'"
          shell_exec("#{command}")

        end


        def attach_isofile
          full_iso_file=File.join(env.config.veewee.iso_dir,definition.iso_file)
          env.ui.info "Mounting cdrom: #{full_iso_file}"
          #command => "${vboxcmd} storageattach '${vname}' --storagectl 'IDE Controller' --type dvddrive --port 1 --device 0 --medium '${isodst}' ";
          command ="#{@vboxcmd} storageattach '#{name}' --storagectl 'IDE Controller' --type dvddrive --port 1 --device 0 --medium '#{full_iso_file}'"
          shell_exec("#{command}")
        end


        def add_floppy_controller
          # Create floppy controller
          unless definition.floppy_files.nil?

            command="#{@vboxcmd} storagectl '#{name}' --name 'Floppy Controller' --add floppy"
            shell_exec("#{command}")
          end
        end


        def attach_floppy
          unless definition.floppy_files.nil?

            # Attach floppy to machine (the vfd extension is crucial to detect msdos type floppy)
            floppy_file=File.join(definition.path,"virtualfloppy.vfd")
            command="#{@vboxcmd} storageattach '#{name}' --storagectl 'Floppy Controller' --port 0 --device 0 --type fdd --medium '#{floppy_file}'"
            shell_exec("#{command}")
          end
        end

        def vbox_os_type_id(veewee_type_id)
          type=env.ostypes[veewee_type_id][:vbox]
          env.logger.info("Using VBOX os_type_id #{type}")
          return type
        end

        def create_vm
          command="#{@vboxcmd} createvm --name '#{name}' --ostype '#{vbox_os_type_id(definition.os_type_id)}' --register"

          #Exec and system stop the execution here
          shell_exec("#{command}")

          env.ui.info "Creating vm #{name} : #{definition.memory_size}M - #{definition.cpu_count} CPU - #{vbox_os_type_id(definition.os_type_id)}"

          #setting cpu's
          command="#{@vboxcmd} modifyvm '#{name}' --cpus #{definition.cpu_count}"
          shell_exec("#{command}")

          #setting memory size
          command="#{@vboxcmd} modifyvm '#{name}' --memory #{definition.memory_size}"
          shell_exec("#{command}")

          #setting bootorder
          command="#{@vboxcmd} modifyvm '#{name}' --boot1 disk --boot2 dvd --boot3 none --boot4 none"
          shell_exec("#{command}")

          # Modify the vm to enable or disable hw virtualization extensions
          vm_flags=%w{pagefusion acpi ioapic pae hpet hwvirtex hwvirtexcl nestedpaging largepages vtxvpid synthxcpu rtcuseutc}

          vm_flags.each do |vm_flag|
            if definition.instance_variable_defined?("@#{vm_flag}")
              vm_flag_value=definition.instance_variable_get("@#{vm_flag}")
              env.ui.info "Setting VM Flag #{vm_flag} to #{vm_flag_value}"
              env.ui.warn "Used of #{vm_flag} is deprecated - specify your options in :virtualbox => { : vm_options => [\"#{vm_flag}\" => \"#{vm_flag_value}\"]}"
              command="#{@vboxcmd} modifyvm #{name} --#{vm_flag.to_s} #{vm_flag_value}"
              shell_exec("#{command}")
            end
          end

          unless definition.virtualbox[:vm_options][0].nil?
            definition.virtualbox[:vm_options][0].each do |vm_flag,vm_flag_value|
              env.ui.info "Setting VM Flag #{vm_flag} to #{vm_flag_value}"
              command="#{@vboxcmd} modifyvm #{name} --#{vm_flag.to_s} #{vm_flag_value}"
              shell_exec("#{command}")
            end
          end

        end
      end
    end
  end
end
