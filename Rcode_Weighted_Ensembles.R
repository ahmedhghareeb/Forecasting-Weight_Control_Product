library(forecast)
library(randomForest)

data=read.csv("D:/Pinsker/MSCA/Time_Series/Project/advertising-and-sales-data.csv")
data=data[,2:3]
data$Month=rep(1:12,3)

###############################################
# Define Modelers used in the Ensembled Model:
###############################################
# Model 1
mod1.modeller <- function(form, data) {
    library(randomForest) 
    randomForest(Sales ~ Advertising, data=data, ntree=500)
}

mod1.predictor <- function(model, data) {
    return(predict(model, newdata=data))
}

mod1.fitted <- function(model) {
    return(predict(model))
}


# Model 2
mod2.modeller <- function(form, data) {
    randomForest(Sales ~ Advertising + Month, data=data, ntree=500) 
}

mod2.predictor <- function(model, data) {
    return(predict(model, newdata=data))
}

mod2.fitted <- function(model) {
    return(predict(model))
}


# Model 3
mod3.modeller <- function(form, data) {
    data=ts(data, start=1, frequency=12)
    Arima(data[,2], order=c(0,1,1), xreg=cbind(data[,1]), method="ML", include.mean=FALSE)
}

mod3.predictor <- function(model, data) {
    return(forecast(model, nrow(data), xreg=data[,1])$mean)
}

mod3.fitted <- function(model) {
    return(model$x + model$residuals)
}


# Model 4
mod4.modeller <- function(form, data) {
    data=ts(data, start=1, frequency=12)
    Arima(data[,2], order=c(2,0,2), xreg=cbind(data[,1], data[,3]), method="ML", include.mean=FALSE)
}

mod4.predictor <- function(model, data) {
    return(forecast(model, nrow(data), xreg=cbind(data[,1], data[,3]))$mean)
}

mod4.fitted <- function(model) {
    return(model$x + model$residuals)
}

# Model 5
mod5.modeller <- function(form, data) {
    data=ts(data, start=1, frequency=5)
    Arima(data[,2], order=c(3,0,2), seasonal=c(0,1,0), method="ML")
}

mod5.fitted <- function(model) {
    return(model$x + model$residuals)
}

mod5.predictor <- function(model, data) {
    return(forecast(model, nrow(data)))
}

# Model 6
mod6.modeller <- function(form, data) {
    data=ts(data, start=1, frequency=6)
    Arima(data[,2], order=c(0,0,1), seasonal=c(1,0,0), method="ML")
}

mod6.fitted <- function(model) {
    return(model$x + model$residuals)
}

mod6.predictor <- function(model, data) {
    return(forecast(model, nrow(data)))
}

# Model 7
mod7.modeller <- function(form, data) {
    library(e1071)
    svm(Sales ~ Advertising +factor(Month), data=data)
}

mod7.predictor <- function(model, short.data, next.data, long.data) {
    next.start = nrow(short.data) + 1
    next.end   = nrow(long.data)
    return(predict(model, long.data)[next.start:next.end])
}

mod7.fitted <- function(model) {
    return(predict(model))
}

###############################################
# Define Ensembled Model:
###############################################
ensemble.modeller <- function(form, data, yCol=2) {
    
    min.essemble=99999999999999
    
    # Collects predictions from several classifiers.
    model = list(model1 = mod1.modeller(form, data), 
                 model2 = mod2.modeller(form, data), 
                 model3 = mod3.modeller(form, data),
                 model4 = mod4.modeller(form, data),
                 model5 = mod5.modeller(form, data),
                 model6 = mod6.modeller(form, data),
                 model7 = mod7.modeller(form, data))
    
    fitted = list(model1.fitted = mod1.fitted(model$model1),
                  model2.fitted = mod2.fitted(model$model2),
                  model3.fitted = mod3.fitted(model$model3, data),
                  model4.fitted = mod4.fitted(model$model4, data),
                  model5.fitted = mod5.fitted(model$model5, data),
                  model6.fitted = mod6.fitted(model$model6, data),
                  model7.fitted = mod7.fitted(model$model7))
    
    error = list(model1.error = mod1.fitted(model$model1) - data[,yCol],
                 model2.error = mod2.fitted(model$model2) - data[,yCol],
                 model3.error = mod3.fitted(model$model3, data) - data[,yCol],
                 model4.error = mod4.fitted(model$model4, data) - data[,yCol],
                 model5.error = mod5.fitted(model$model5, data) - data[,yCol],
                 model6.error = mod6.fitted(model$model6, data) - data[,yCol],
                 model7.error = mod7.fitted(model$model7) - data[,yCol])
    
    fitted.data = as.data.frame(do.call(cbind, fitted))
    error.data = as.data.frame(do.call(cbind, error))
    invVar=1/(error.data^2)
    
    prob=round(invVar/rowSums(invVar),2)
    
    for (k in 1:nrow(prob)) {
        
        a=data.frame(matrix(0, nrow=nrow(fitted.data), ncol=numModel))
        
        for (i in 1:nrow(fitted.data)) {
            
            for (j in 1:numModel) {
                
                a[i,j]=fitted.data[i,j]*prob[k,j]
                
            }
        }
        
        tot_variance=sum((rowSums(a) - data[,yCol])^2)
        
        while(tot_variance < min.essemble) {
            min.essemble = tot_variance
            weighted.factor=prob[k,]
        }
    }
    
    return(weighted.factor)
}

###############################################
# Define te prediciton of the Ensembled Model:
###############################################
ensemble.predict <- function(form, data, newdata, yCol=2, ensemble.prob) {
    
    # Collects predictions from several classifiers.
    model = list(model1 = mod1.modeller(form, data), 
                 model2 = mod2.modeller(form, data), 
                 model3 = mod3.modeller(form, data),
                 model4 = mod4.modeller(form, data))
    
    predicted = list(model1.predicted = mod1.predictor(model$model1, newdata),
                     model2.predicted = mod2.predictor(model$model2, newdata),
                     model3.predicted = mod3.predictor(model$model3, newdata),
                     model4.predicted = mod4.predictor(model$model4, newdata))
    
    predicted.data = as.data.frame(do.call(cbind, predicted))
    
    
    ensemble.prediction=data.frame(matrix(0, nrow=nrow(predicted.data), ncol=numModel))                    
    for (i in 1:nrow(predicted.data)) {
        for (j in 1:numModel) {
            
            ensemble.prediction[i,j]=predicted.data[i,j]*prob[j]
            
        }
    }
    
    return(rowSums(ensemble.prediction))
}


#############################################
# Test the performance of ensembling method
#############################################
## fitted plot
data=read.csv("D:/Pinsker/MSCA/Time_Series/Project/advertising-and-sales-data.csv")
data=data[,2:3]
data$Month=rep(1:12,3)

model = list(model1 = mod1.modeller(form, data), 
             model2 = mod2.modeller(form, data), 
             model3 = mod3.modeller(form, data),
             model4 = mod4.modeller(form, data),
             model5 = mod5.modeller(form, data),
             model6 = mod6.modeller(form, data),
             model7 = mod7.modeller(form, data))

fitted = list(model1.fitted = mod1.fitted(model$model1),
              model2.fitted = mod2.fitted(model$model2),
              model3.fitted = mod3.fitted(model$model3),
              model4.fitted = mod4.fitted(model$model4),
              model5.fitted = ts(mod5.fitted(model$model5), start=1, frequency=12),
              model6.fitted = ts(mod6.fitted(model$model6), start=1, frequency=12),
              model7.fitted = mod7.fitted(model$model7))

error = list(model1.error = mod1.fitted(model$model1) - data[,yCol],
             model2.error = mod2.fitted(model$model2) - data[,yCol],
             model3.error = mod3.fitted(model$model3) - data[,yCol],
             model4.error = mod4.fitted(model$model4) - data[,yCol],
             model5.error = ts(mod5.fitted(model$model5), start=1, frequency=12) - data[,yCol],
             model6.error = ts(mod6.fitted(model$model6), start=1, frequency=12) - data[,yCol],
             model7.error = mod7.fitted(model$model7) - data[,yCol])

numModel=length(model)

fitted.data = as.data.frame(do.call(cbind, fitted))
error.data = as.data.frame(do.call(cbind, error))

invVar=1/(error.data^2)
prob=round(invVar/rowSums(invVar),2)
prob=round(colMeans(prob),3)

ensemble.result=matrix(0,nrow(fitted.data))
for (i in 1:nrow(fitted.data)) {
    for (j in 1:length(prob)) {
        ensemble.result[i]=ensemble.result[i]+fitted.data[i,j]*prob[j]
    }
}

(rmse=sqrt(mean((ensemble.result-data[,2])^2)))

ts.plot(ts(data[,2], start=c(1980,1), frequency=12),
        ts(ensemble.result, start=c(1980,1), frequency=12),
        col=c("black", "red"), ylim=c(0,80), ylab="Sales")

legend("topleft",
       legend=c("actual values","fitted values using ensembled model (model1+model2+model6)"),
       col=c("black","red"),lwd=1,bty='n',cex=0.7)


################################
# TS-CV for the ensembed model:
################################
data=read.csv("D:/Pinsker/MSCA/Time_Series/Project/advertising-and-sales-data.csv")
data=data[,2:3]
data$Month=rep(1:12,3)

k = 18 # minimum data length for fitting a model
n = nrow(data)
mae.wf <- matrix(NA,n-k,12)

tmp.data=ts(data, start=1, frequency=12)
st = tsp(tmp.data)[1]+(k-2)/12

for(i in 1:(n-k))
{
    xshort = window(tmp.data, end=st+i/12)
    xnext  = window(tmp.data, start=st+(i+1)/12, end=st+(i+12)/12)
    xlong  = window(tmp.data, end=st+(i+12)/12)
    
    model = list(model1 = mod1.modeller(form, xshort), 
                 model2 = mod2.modeller(form, xshort), 
                 model3 = mod3.modeller(form, xshort),
                 model4 = mod4.modeller(form, xshort),
                 model5 = mod5.modeller(form, xshort),
                 model6 = mod6.modeller(form, xshort),
                 model7 = mod7.modeller(form, xshort))
    
    fitted = list(model1.fitted = mod1.fitted(model$model1),
                  model2.fitted = mod2.fitted(model$model2),
                  model3.fitted = mod3.fitted(model$model3),
                  model4.fitted = mod4.fitted(model$model4),
                  model5.fitted = ts(mod5.fitted(model$model5), start=1, frequency=12),
                  model6.fitted = ts(mod6.fitted(model$model6), start=1, frequency=12),
                  model7.fitted = mod7.fitted(model$model7)) 
    
    error = list(model1.error = mod1.fitted(model$model1) - xshort[,yCol],
                 model2.error = mod2.fitted(model$model2) - xshort[,yCol],
                 model3.error = mod3.fitted(model$model3) - xshort[,yCol],
                 model4.error = mod4.fitted(model$model4) - xshort[,yCol],
                 model5.error = ts(mod5.fitted(model$model5), start=1, frequency=12) - xshort[,yCol],
                 model6.error = ts(mod6.fitted(model$model6), start=1, frequency=12) - xshort[,yCol],
                 model7.error = mod7.fitted(model$model7) - xshort[,yCol]) 
    
    forecasted = list(model1.predicted = ts(mod1.predictor(model$model1, xnext), start=1, frequency=12),
                      model2.predicted = ts(mod2.predictor(model$model2, xnext), start=1, frequency=12),
                      model3.predicted = ts(mod3.predictor(model$model3, xnext), start=1, frequency=12),
                      model4.predicted = ts(mod4.predictor(model$model4, xnext), start=1, frequency=12),
                      model5.predicted = ts(mod5.predictor(model$model5, xnext)$mean, start=1, frequency=12),
                      model6.predicted = ts(mod6.predictor(model$model6, xnext)$mean, start=1, frequency=12),
                      model7.predicted = ts(mod7.predictor(model$model7, xshort, xnext, xlong), start=1, frequency=12))
    
    numModel=length(model)
    
    fitted.data     = as.data.frame(do.call(cbind, fitted))
    error.data      = as.data.frame(do.call(cbind, error))
    forecasted.data = as.data.frame(do.call(cbind, forecasted))
    
    invVar=1/(error.data^2)
    prob=round(invVar/rowSums(invVar),2)
    prob=round(colMeans(prob),3)
    
    ensemble.result=matrix(0,nrow(forecasted.data))
    for (p in 1:nrow(forecasted.data)) {
        for (q in 1:length(prob)) {
            ensemble.result[p]=ensemble.result[p]+forecasted.data[p,q]*prob[q]
        }
    }
    
    mae.wf[i,1:nrow(xnext)] = abs(ensemble.result-xnext[,2])
}


plot(1:12, sqrt(colMeans(mae1^2,na.rm=TRUE)), type="l", col="red", xlab="horizon", ylab="RMSE of Forecasting", ylim=c(15,25))
lines(1:12, sqrt(colMeans(mae1.rf^2,na.rm=TRUE)), type="o", lty=2, col="red")
lines(1:12, sqrt(colMeans(mae2^2,na.rm=TRUE)), type="l", col="blue")
lines(1:12, sqrt(colMeans(mae2.rf^2,na.rm=TRUE)), type="o", lty=2, col="blue")
lines(1:12, sqrt(colMeans(mae3^2,na.rm=TRUE)), type="l", col="orange", lwd=1)
lines(1:12, sqrt(colMeans(mae4.202^2,na.rm=TRUE)), type="l", col="magenta", lwd=1)
lines(1:12, sqrt(colMeans(mae4.000^2,na.rm=TRUE)), type="l", col="green", lwd=1)
lines(1:12, sqrt(colMeans(mae5^2,na.rm=TRUE)), type="o", lty=2, col="darkgreen", lwd=2)
lines(1:12, sqrt(colMeans(mae6^2,na.rm=TRUE)), type="o", lty=3, col="purple", lwd=2)
lines(1:12, sqrt(colMeans(mae.wf^2,na.rm=TRUE)), type="o", lty=2, col="magenta", lwd=2)

legend("topleft",legend=c("Model 1","Model 1 (using Random Forest, ntree=500)","Model 2","Model 2 (using Random Forest)","Model 3 (Model 1 w/ ARIMA(0,1,1) error)","Model 4 (Model 2 w/ ARIMA(0,0,0) error)","Model 6: sARIMA(0,0,1)(1,0,0)[6]","Ensembled model"), col=c("red","red","blue","blue","orange","green","purple","magenta"), lty=c(1,2,1,2,1,1,3,2), cex=0.6, bty="n")
