
Hops installer
===

recipes:

* install.rb
* namenode.rb
* datanode.rb


## AWS VPC Instructions for Karamel

1. Try and use a default VPC - it's much easier :)

If you have to create a VPC, then you need to make sure that:
 1. Tenancy should be dedicated (for better performance)
 2. DNS Resolution must be activated (yes)
 3. DNS Hostnames must be activated (yes)
 4. Your attached subnets must have auto-assigned public IP enabled
 5. Your attached Internet Gateways should have global (public) access for all IPs enabled
You can set the VPC properties when you both create the VPC and using the 'action' button in the VPC menu page.


 
##Roadmap

Roadmap

This is still very much a work-in-progress, but stay tuned for updates as we continue development. If you have ideas or patches, feel free to contribute!

- [x] Launching Hops using Karamel/Vagrant
  1. Implement Karamel Scheduler and DAG API
  1. Launch it!
- [x] Chef orchestration 
- [x] AngularJs NgSortable
- [ ] Integration in Hops Dashboard
- [ ] Middleware for performance

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
