library(igraph)
#importing files
source("/home/nejat/thesis/github/graph_theory/codes/deltaQ.r")
source("/home/nejat/thesis/github/graph_theory/codes/modularity2.r")

### TO DO - SELF_LOOP ile ilgili bir sıkıntı cıkıp cıkmama olasılıgına bak!
  #nb_selfLoops = function(g, node){
  #  res <- which(node == neighbors(g, node))
  #  if(lenght(res) == 0){
  #    return(0)
  #  }
  #  else{
  #    return(g[node, node])
  #  }
  #}

##read a graph - begin
g <- read.graph("/home/nejat/thesis/data/toydata.edgelist", format=c("edgelist"), directed=FALSE)
E(g)$weight <- read.table("/home/nejat/thesis/data/toydata.weight")$V1
## end


partition2graph_binary = function(g, mems){

    different_comm <- unique(mems)
    #rename communities - begin
    new_str <- vector(mode="integer",length=length(mems))
    final <- 1
    length_row <- 0 # ayni zamanda, community'ler arasinda en cok node'u olanin node sayisini bulucaz
    for(node in 1:length(different_comm)){
      vec <- different_comm[node]
      #secilen community'ye ait kac node oldugunu buluyoruz
      correspondant <- which(vec == mems)

      new_str[correspondant] <- final
      final <- final + 1

      #tum community'lere kiyasla bir community'deki max node sayisini bulma icin
      cur_length <- length(correspondant)
      if(length_row < cur_length){
        length_row <- cur_length
      }
    }
    # end

    #max node sayisini bulduktan sonra matrix'i olusturabiliriz
    #matrix, inner_node bilgisi icin gerekli olacak veri yapimiz
    #matrix'i once sifirla initialize ettik
    mat <- matrix(0,nrow=length_row,ncol=length_row)
    #satirlar, her community'nin sahip oldugu node'lari iceriyor
    
    for(comm in 1:length(different_comm)){
      inner_nodes_in_comm <- which(comm == new_str)
      mat[comm, 1:length(inner_nodes_in_comm)] <- inner_nodes_in_comm
    }

    g1 <- induced.subgraph(g, mat[1, which(mat[1,] != 0)])
    E(g1)$weight <- 1
    for(comm in 2:length(different_comm)){
      #g1 ile g2 arasinda weight'i bulup edge()'e eklemen lazim
      g2 <- induced.subgraph(g, mat[1, which(mat[1,] != 0)])
      #g1[1,2] yaparsak oluyor -> ekliyo weight'i
      g1 <- g1 %du% g2# + edge('1', '6') + edge('1', '11')
      E(g2)$weight <- 1
    }

  return(g1)
}

louvain = function(g, verbose=FALSE, nb_pass=10000){

  precision <- 0.000001
  comm_str <- seq(1, gSize) #each node is a community at beginning
  mod <- modularity2(g, comm_str)

  lvl <- one_level(g,FALSE)

  g <- partition2graph_binary()
  
  while((new_mod-mod)>precision){
    mod <- new_mod
    lvl <- one_level(g,FALSE)
    mems <- lvl$membership

    g <- partition2graph_binary()
  }
}

one_level = function(g, verbose=FALSE, nb_pass=10000){
  gSize <- vcount(g)
  comm_str <- seq(1, gSize) #each node is a community at beginning
  cur_mod <- new_mod <- modularity2(g, comm_str)
  min_modularity <- 0.000001

  #while init - begin
  improvement <- TRUE
  nb_pass_done <- 0
  new_mod <- new_mod+0.1 #while'a ilk girişte sorun çıkarmasın diye => cünkü new_mod must be > cur_mod
  #end

  memberships <- c()

  while(improvement && (new_mod-cur_mod)>min_modularity && nb_pass_done!=nb_pass){
    #init - begin
    improvement <- FALSE
    cur_mod <- new_mod
    nb_pass_done = nb_pass_done+1
    #init - end

    for(node_tmp in 1:gSize){
      node <- node_tmp
      node_comm <- comm_str[node]
      
      #computation of all neighboring communities of current node
      neigh <- neighbors(g, node)
      ncomm <- neigh[which(comm_str[neigh] != node_comm)]
      
      #if any neighboring communities of current node exist
      if(length(ncomm) != 0){
        #remove node from its current community
        comm_str[node] <- -1
        
        best_comm <- node_comm
        best_increase <- 0
        for(i in 1:length(ncomm)){
          next_neigh_comm = ncomm[i]
          increase <- deltaQ(g, node, next_neigh_comm)
          if(best_increase < increase){
            best_comm <- next_neigh_comm
            best_increase <- increase
          }
        }

        #insert node in the nearest community
        comm_str[node] <- best_comm

        if(best_comm != node_comm){
          improvement <- TRUE
        }

        new_mod <- modularity2(g, comm_str)

        if(verbose){
          cat(sprintf("pass_number: %d of %d (nb_pass) => new_mod=%s, cur_mod=%s\n", nb_pass_done, nb_pass, new_mod, cur_mod))
    cat("community structure: ", comm_str, "\n")
        }
      }
    }
    memberships <- c(memberships, comm_str)
  }

  return(list("modularity" = new_mod, "membership" = comm_str, "memberships" = matrix(memberships,nrow=nb_pass_done)))
}