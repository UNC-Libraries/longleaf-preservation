## About Longleaf

Longleaf, developed at the University of North Carolina at Chapel Hill University Libraries, is an open-source, portable digital preservation tool, designed to enable the creation and application of highly configurable preservation plans for large and varied collections of digital content across multiple systems.

Longleaf addresses challenges we have encountered over the past 20 years of growing and managing our digital collections infrastructure, which we feel are shared by other institutions:

1. Preservation activities being applied to files based on system affiliation (i.e. repository platform or lack thereof) rather than the needs of the content.

1. Difficulty maintaining an ideal schedule of fixity checks as the sizes of our collections grow.

1. Physical and computational costs to servers and storage devices imposed by ongoing cryptographic checksum algorithms (Altman et al., 2013).

1. Difficulty gradually introducing cloud storage services into our replication strategy for vulnerable files.

The goal for Longleaf is to provide organizations with a flexible tool for creating and implementing tailored preservation practices across the scope of their content, based on appropriate levels of digital preservation need (Phillips, Bailey, Goethals, & Owens, 2013). To this end, we have designed Longleaf according to the principles of high “software availability” (Davidson & Casden, 2016) that prioritize ease of use by a broad set of users in a variety of environments. 

The Longleaf application is a command-line utility that will run on any modern Linux operating system with only a ruby interpreter. Longleaf can be applied to any content storage system with a file system, and requires no repository, no external database, and no storage system other than the file system. It can be run completely from the command line or triggered by arbitrary external systems (e.g. initiated on file ingest). Preservation processes are targeted at the file and storage level rather than through a repository system intermediary, allowing files managed in temporary storage or non-preservation asset management systems to benefit from the same replication and verification processes as those ingested into preservation repositories. For example, in our own digital collections context, we will be applying Longleaf to content across a wide variety of systems, including files managed entirely on shared drives, files managed by Fedora-based repositories, as well as digitization masters managed by CONTENTdm. 

Longleaf’s modular architecture and flexible configuration system reduce the interference of repository system constraints, to enable needs-based digital preservation planning processes such as evaluating and configuring specific preservation activities across subsets of larger collections. For our collections, we are using Longleaf to begin addressing specific challenges such as managing the physical and computational costs of large-scale fixity verification, and integrating storage endpoints with different access costs. For example, we are increasing coverage of ongoing and transactional fixity checks (Gallinger, Bailey, Cariani, Owens, & Altman, 2017) by providing typical cryptographic checksums alongside more scaleable non-cryptographic checks and filesystem checks. We can also determine more appropriate replication and verification schedules and techniques overall, based on the characteristics of both the source and destination storage locations for content. 

## References
Altman, M., Bailey, J., Cariani, K., Gallinger, M., Mandelbaum, J., & Owens, T. (2013). NDSA Storage Report: Reflections on National Digital Stewardship Alliance Member Approaches to Preservation Storage Technologies. D-Lib Magazine, 19(5/6). https://doi.org/10.1045/may2013-altman

Davidson, B., & Casden, J. (2016). Beyond open source. Code4Lib Journal, Issue 31. Retrieved from http://journal.code4lib.org/articles/11148

Gallinger, M., Bailey, J., Cariani, K., Owens, T., & Altman, M. (2017). Trends in Digital Preservation Capacity and Practice: Results from the 2nd Bi-annual National Digital Stewardship Alliance Storage Survey. D-Lib Magazine, 23(7/8). https://doi.org/10.1045/july2017-gallinger

Phillips, M., Bailey, J., Goethals, A., & Owens, T. (2013). The NDSA levels of digital preservation: Explanation and uses. In Archiving Conference (Vol. 2013, pp. 216–222). Society for Imaging Science and Technology.
