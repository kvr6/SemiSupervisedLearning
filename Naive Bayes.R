library(DMwR)
library(e1071)
library(caret)
library(SDMTools)

mydata = read.csv("C:/Personal/krajan/YelpReviewData.csv")
c=which(is.na(mydata$cosinecost))
mydata$cosinecost[c]=0

data = mydata[c("review_length","abs_dev","MNRcount","cosinecost","Class")]
##Shuffle data
data <- data[sample(nrow(data)),]

#####Divide data into training and test set
ptrain=0.7
indices=sample(nrow(data), ptrain*nrow(data), replace = FALSE);
trdata=data[indices,]
tsdata=data[-indices,]


#############################################
nldata=c(50,100,150,200,300,500,700,900,1200, 1500, 2000, 2500)
#nldata = c(0,50,150,300,500,800,1200,1900,2800,4000,5500,7500,10500)
maxldata=sum(nldata)

trdata <- trdata[sample(nrow(trdata)),]   #Shuffle Training data
uldata = trdata[(maxldata+1):nrow(trdata),]
uldata$Class = NA

trlabeled = trdata[1:maxldata,]
trdataone=trlabeled[which(trlabeled$Class==1),]
cat("len of trdataone",nrow(trdataone))
trdatazero=trlabeled[which(trlabeled$Class==0),]
cat("len of trdatazero",nrow(trdatazero))

resultlist = list()
for( itr in 1:10){
    semisupresult = data.frame(SupervisedAcc=double(),SemiSupervisedAcc=double())
    resultlistSup=list((rep(0, length(nldata))))
    resultlistUnSup=list((rep(0, length(nldata))))
    trdataone=trlabeled[which(trlabeled$Class==1),]
    trdatazero=trlabeled[which(trlabeled$Class==0),]
    trdataone <- trdataone[sample(nrow(trdataone)),]   #Shuffle Training data One
    trdatazero <- trdatazero[sample(nrow(trdatazero)),]   #Shuffle Training data Zero
    
    for (i in 1:length(nldata)) {
        cat(nldata[i],"\n")
        valone=0.9*nldata[i]
        valzero=0.1*nldata[i]
        if (valone > nrow(trdataone)){
            break
        }
        valone = ifelse(valone < nrow(trdataone), valone, nrow(trdataone))
        oneidx=sample(nrow(trdataone),valone,replace = FALSE)
        ldataone=trdataone[oneidx,]
        trdataone=trdataone[-oneidx,]
        cat("len of trdataone",nrow(trdataone),"\n")
        valzero = ifelse(valzero < nrow(trdatazero), valzero, nrow(trdatazero))
        zeroidx=sample(nrow(trdatazero),valzero,replace = FALSE)
        ldatazero=trdatazero[zeroidx,]
        trdatazero=trdatazero[-zeroidx,]
        cat("len of trdatazero",nrow(trdatazero),"\n")
        
        ldata = rbind(ldataone,ldatazero)
        
        
        ##Model for labeled data
        model.nb=naiveBayes(Class~., data=ldata)
        pred.nb=data.frame(predict(model.nb, tsdata[,-5], type="raw"))
        pred.nb$label=sapply(1:nrow(pred.nb), function(x) ifelse(pred.nb[x,]$X0>=pred.nb[x,]$X1, 0, 1))
        table.nb=confusion.matrix(tsdata$Class,pred.nb$label, threshold = 0.5)
        sup.accuracy = (table.nb[1,1]+table.nb[2,2])/sum(table.nb)
        #cmsup = confusionMatrix(pred.nb$label,tsdata$Class)
        #sup.accuracy = cmsup$overall['Accuracy']
        #Combine labeled and ulabled data
        semi.sup.data <- rbind(ldata, uldata)
        
        #Function for self train
        predfunc.nb <- function(m,d) {
            pl <- predict(m,d,type='raw')
            data.frame(cl=colnames(pl)[apply(pl,1,which.max)],p=apply(pl,1,max))
        }
        
        #SelfTrain
        nbST <- SelfTrain(Class ~ .,semi.sup.data,learner('naiveBayes',list()),'predfunc.nb',thrConf = 0.999, maxIts = 10, verbose = FALSE,percFull = 0.8)
    
        pred.nb=data.frame(predict(nbST,tsdata[,-5],type="raw"))
        pred.nb$label=sapply(1:nrow(pred.nb), function(x) ifelse(pred.nb[x,]$X0>=pred.nb[x,]$X1, 0, 1))
    
        table.nb=confusion.matrix(tsdata$Class,pred.nb$label, threshold = 0.5)
        unsup.accuracy = (table.nb[1,1]+table.nb[2,2])/sum(table.nb)
        #cmunsup = confusionMatrix(pred.nb$label,tsdata$Class)
        #unsup.accuracy = cmunsup$overall['Accuracy']
    
        semisupresult[i,]=c(sup.accuracy,unsup.accuracy)
        resultlistSup[[1]][i]=resultlistSup[[1]][i]+sup.accuracy
        resultlistUnSup[[1]][i]=resultlistUnSup[[1]][i]+unsup.accuracy
    }
    cat("Adding Result",itr,"\n")
    resultlist = c(resultlist,semisupresult)
}

nldatax=c("50","100","150","200","300","500","700","900","1200", "1500", "2000", "2500")
xrange = range(12)
yrange = range(semisupresult$SupervisedAcc)
x=c(1:12)
plot(xrange, yrange, type="n", xlab="Number of Labled data",ylab="Accuracy" )
lines(nldatax, semisupresult$SupervisedAcc, type="b", lwd=1.5, lty=1, col="red", pch=18)
lines(nldatax, semisupresult$SemiSupervisedAcc, type="b", lwd=1.5, lty=2, col="darkblue", pch=22)

# add a title and subtitle 
title("Semi Supervised Learning")
# add a legend 
legend("topright", c("No Unlabeled data","14300 Unlabeled data"), cex=0.8, col=c("red","darkblue"),
  	pch=c(18,20), lty=c(1,2), title="14300 Unlabeled data")
