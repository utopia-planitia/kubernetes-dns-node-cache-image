# Kubernetes/DNS Node Cache Image

A distroless container image with node-cache ([kubernetes/dns](https://github.com/kubernetes/dns)) and iptables.

We use the “NodeLocal DNSCache” (see <https://kubernetes.io/docs/tasks/administer-cluster/nodelocaldns/>) in our Kubernetes clusters.

We install it using this manifest: <https://github.com/kubernetes/kubernetes/blob/master/cluster/addons/dns/nodelocaldns/nodelocaldns.yaml>

The image used in this manifest is a distroless image comes bundled with iptables 1.8.7. This was fine while our cluster nodes and kube-router used the same iptables version, too. But recently kube-router updated to iptables 1.8.8.

When it did, node-cache started to create the nodelocaldns firewall rules over and over again because the command to check if the rules already exist failed more often than it succeeded. After a while there were thousands of identical nodelocaldns firewall rules causing high load on the nodes and slowing the network down.

We updated iptables on our cluster nodes to v1.8.8, and when we update the iptables version of the node-cache image, too, the issue with the failing rule check and the duplicate firewall rules disappears.

There does not seem to be an official node-cache image with an iptables version higher than 1.8.7 (as of February 2023) so we need to build it ourselves.
