function [P_final,Corr_out,iterations]=NRtracking3(varargin)
	for i=1:nargin/2
		switch varargin{i*2-1}
		case 'subset size'
			subsize=varargin{i*2};
		case 'subset position'
			subpos=varargin{i*2};
		case 'undeformed image'
			F_in=varargin{i*2};
		case 'deformed image'
			G_in=varargin{i*2};
		case 'guess'
			Pinitial=varargin{i*2};
		case 'coef'
			coef=varargin{i*2};%warp function
		case 'warp2'
			Warp2_func=varargin{i*2};% Jacobian
		case 'warp3'
			Warp3_func=varargin{i*2};%warp matrix
		case 'stepsize'
			stepsize=varargin{i*2};
		case 'coef_shift'
			coef_shift=varargin{i*2};
		end
	end
	G=G_in;
	F=F_in(subpos.coords(1):subpos.coords(3),subpos.coords(2):subpos.coords(4));
	[r,c]=size(F);
	% size(G)
	% meshcompare(F_in,G_in)
	XX=subpos.coords(2):subpos.coords(2)+subsize-1;										% x values over subset
	YY=subpos.coords(1):subpos.coords(1)+subsize-1;										% y values over subset
	X=repmat(XX,r,1);
	Y=repmat(YY',1,c);
	% x0=subsize/2+subpos(1);													% x value for subset centre
	% y0=subsize/2+subpos(2);													% y value for subset centre
	x0=subsize/2+subpos.coords(2);													% x value for subset centre
	y0=subsize/2+subpos.coords(1);													% y value for subset centre
	P=Pinitial;
	[r_g,c_g]=size(G);
	[Xmesh,Ymesh]=meshgrid(1:1:c_g,1:1:r_g);
	InterpFunc=griddedInterpolant(Xmesh',Ymesh',G','cubic');
	flag=0;

	Fmean=mean(mean(F));
	Ftemp=F-ones([subsize, subsize])*Fmean;
	dF_temp=sum(sum(Ftemp.^2));
	dF=sqrt(dF_temp);
	count=0;

	dx=X-x0;
	dy=Y-y0;

	% P_temp=P;
	% clear P;
	% P=[P_temp(1), P_temp(4)];
	testing=0;
	dP_flag=0;
	while flag==0
		count=count+1;
		search_length_flag=0;
		if (count<3)||(mod(count,10)==0)%(count>1)&((norm(stepChange)<0.000001))&(dP_flag==0)
			% if count==1
			% 	dP=[1; 0; 0; 0; 0; 0];
			% elseif count==2
			% 	dP=[0; 0; 0; 1; 0; 0];
			% elseif count==5
			% 	dP=[0; 1; 0; 0; 0; 0];
			% elseif count==6
			% 	dP=[0; 0; 0; 0; 1; 0];
			% elseif count==3
			% 	dP=[0; 0; 1; 0; 0; 0];
			% elseif count==4
			% 	dP=[0; 0; 0; 0; 0; 1];
			% end
					
			if mod(testing,2)==0
				dP=[1;0;0;0;0;0];
				testing=testing+1;
				dP_flag=1;
			elseif mod(testing,2)==1
				dP=[0;0;0;1;0;0];
				testing=testing+1;
				dP_flag=1;
			end
		else
			[G,J,H]=getJac1_eff(coef,P,dy,dx,x0,y0,F,2,subpos,stepsize,coef_shift);
			% [G,J,H,Funcval]=getJac5(coef,P,dy,dx,x0,y0,F);
			% [L,D,C]=AdjustCholesky(H,0.0001);
			% H=C*C';
			dP=H\J;
			dP_flag=0;
		end
		P_store(count,:)=P;
		dP_store(count,:)=dP';
		if count>15
			if mod(count,2)==0
				dP(1)=0;
				dP(4)=0;
			else
				dP(2)=0;
				dP(3)=0;
				dP(5)=0;
				dP(6)=0;
			end
		end
		% if count>1
		% 	dP_check(count,:)=dP_store(count,:)./dP_store(count-1,:)
		% 	if dP_check(count,:)==dP_check(count-1,:)
		% 		search_length_flag=1;
		% 	end
		% end

		% golden section search
		iterMax=600;
		
		r=(sqrt(5)-1)/2;
		% xa=-0.5/norm(dP);
		% xb=0.5/norm(dP);

		xa=-10;
		xb=10;
		tol=1e-10;

		Lo=xb-xa;
	   	for i=1:iterMax
	   		if i==1
	   			lambda1=xa+r^2*Lo;
	   			lambda2=xa+r*Lo;
	   			[G,f1]=getJac1_eff(coef,(P+(dP')*lambda1),dy,dx,x0,y0,F,1,subpos,stepsize,coef_shift);
	   			[G,f2]=getJac1_eff(coef,(P+(dP')*lambda2),dy,dx,x0,y0,F,1,subpos,stepsize,coef_shift);
	   			% [G,J,H,f1]=getJac5(coef,(P+(dP')*lambda1),dy,dx,x0,y0,F);
	   			% [G,J,H,f2]=getJac5(coef,(P+(dP')*lambda2),dy,dx,x0,y0,F);
	   % 			f1=func(x0+U*lambda1);
				% f2=func(x0+U*lambda2);
				i=i+1; %two function evaluations in this if statement (i starts at one so one is included already)
			end
			if f1>=f2
				xa=lambda1;
				lambda1=lambda2;
				Li=xb-xa;
				lambda2=xa+r*Li;
				evaluat=1;
			elseif f2>f1
				xb=lambda2;
				lambda2=lambda1;
				Li=xb-xa;
				lambda1=xa+r^2*Li;
				evaluat=2;
			else
				disp('There is an error in the golden section code (NaN or inf values)')
			end

			if Li<tol
				% P=P+(dP')*(xa+xb)/2
				% n=i;
				break
			else
				if evaluat==1
					f1=f2;
					[G,f2]=getJac1_eff(coef,(P+(dP')*lambda2),dy,dx,x0,y0,F,1,subpos,stepsize,coef_shift);
					% [G,J,H,f2]=getJac5(coef,(P+(dP')*lambda2),dy,dx,x0,y0,F);
					% f2=func(x0+U*lambda2);
				elseif evaluat==2
					f2=f1;
					[G,f1]=getJac1_eff(coef,(P+(dP')*lambda1),dy,dx,x0,y0,F,1,subpos,stepsize,coef_shift);
					% [G,J,H,f1]=getJac5(coef,(P+(dP')*lambda1),dy,dx,x0,y0,F);
					% f1=func(x0+U*lambda1);
				end
			end
		end
		P=P+(dP')*(xa+xb)/2
		% iterations=i
		stepChange=(dP')*(xa+xb)/2

		[G,Funcval]=getJac1_eff(coef,P,dy,dx,x0,y0,F,1,subpos,stepsize,coef_shift);
		% [G,J,H,Funcval]=getJac5(coef,P,dy,dx,x0,y0,F);
		Funcval_store(count)=Funcval;
		Funcval

		% if count>15
		% 	dP_temp_store=dP;
		% 	fprintf('Starting direction check\n');
		% 	for j=1:16
		% 		if j==1
		% 			dP=dP_temp_store.*[0; 1; 1; 0; 1; 1];
		% 		elseif j==2
		% 			dP=dP_temp_store.*[0; -1; 1; 0; 1; 1];
		% 		elseif j==3
		% 			dP=dP_temp_store.*[0; 1; -1; 0; 1; 1];
		% 		elseif j==4
		% 			dP=dP_temp_store.*[0; 1; 1; 0; -1; 1];
		% 		elseif j==5
		% 			dP=dP_temp_store.*[0; 1; 1; 0; 1; -1];
		% 		elseif j==6
		% 			dP=dP_temp_store.*[0; -1; -1; 0; 1; 1];
		% 		elseif j==7
		% 			dP=dP_temp_store.*[0; -1; 1; 0; -1; 1];
		% 		elseif j==8
		% 			dP=dP_temp_store.*[0; -1; 1; 0; 1; -1];
		% 		elseif j==9
		% 			dP=dP_temp_store.*[0; 1; -1; 0; -1; 1];
		% 		elseif j==10
		% 			dP=dP_temp_store.*[0; 1; -1; 0; 1; -1];
		% 		elseif j==11
		% 			dP=dP_temp_store.*[0; 1; 1; 0; -1; -1];
		% 		elseif j==12
		% 			dP=dP_temp_store.*[0; -1; -1; 0; -1; 1];
		% 		elseif j==13
		% 			dP=dP_temp_store.*[0; -1; 1; 0; -1; -1];
		% 		elseif j==14
		% 			dP=dP_temp_store.*[0; -1; -1; 0; 1; -1];
		% 		elseif j==15
		% 			dP=dP_temp_store.*[0; 1; -1; 0; -1; -1];
		% 		elseif j==16
		% 			dP=dP_temp_store.*[0; -1; -1; 0; -1; -1];
		% 		end
					
						
		% 	   	for i=1:iterMax
		% 	   		if i==1
		% 	   			lambda1=xa+r^2*Lo;
		% 	   			lambda2=xa+r*Lo;
		% 	   			[G,f1]=getJac1_eff(coef,(P+(dP')*lambda1),dy,dx,x0,y0,F,1,subpos,stepsize,coef_shift);
		% 	   			[G,f2]=getJac1_eff(coef,(P+(dP')*lambda2),dy,dx,x0,y0,F,1,subpos,stepsize,coef_shift);
		% 	   			% [G,J,H,f1]=getJac5(coef,(P+(dP')*lambda1),dy,dx,x0,y0,F);
		% 	   			% [G,J,H,f2]=getJac5(coef,(P+(dP')*lambda2),dy,dx,x0,y0,F);
		% 	   % 			f1=func(x0+U*lambda1);
		% 				% f2=func(x0+U*lambda2);
		% 				i=i+1; %two function evaluations in this if statement (i starts at one so one is included already)
		% 			end
		% 			if f1>=f2
		% 				xa=lambda1;
		% 				lambda1=lambda2;
		% 				Li=xb-xa;
		% 				lambda2=xa+r*Li;
		% 				evaluat=1;
		% 			elseif f2>f1
		% 				xb=lambda2;
		% 				lambda2=lambda1;
		% 				Li=xb-xa;
		% 				lambda1=xa+r^2*Li;
		% 				evaluat=2;
		% 			else
		% 				disp('There is an error in the golden section code (NaN or inf values)')
		% 			end

		% 			if Li<tol
		% 				% P=P+(dP')*(xa+xb)/2
		% 				% n=i;
		% 				break
		% 			else
		% 				if evaluat==1
		% 					f1=f2;
		% 					[G,f2]=getJac1_eff(coef,(P+(dP')*lambda2),dy,dx,x0,y0,F,1,subpos,stepsize,coef_shift);
		% 					% [G,J,H,f2]=getJac5(coef,(P+(dP')*lambda2),dy,dx,x0,y0,F);
		% 					% f2=func(x0+U*lambda2);
		% 				elseif evaluat==2
		% 					f2=f1;
		% 					[G,f1]=getJac1_eff(coef,(P+(dP')*lambda1),dy,dx,x0,y0,F,1,subpos,stepsize,coef_shift);
		% 					% [G,J,H,f1]=getJac5(coef,(P+(dP')*lambda1),dy,dx,x0,y0,F);
		% 					% f1=func(x0+U*lambda1);
		% 				end
		% 			end
		% 		end
		% 		P_check(j,:)=P+(dP')*(xa+xb)/2
		% 		% iterations=i
		% 		stepChange_check(j,:)=(dP')*(xa+xb)/2

		% 		[G,Funcval]=getJac1_eff(coef,P,dy,dx,x0,y0,F,1,subpos,stepsize,coef_shift);
		% 		Funcval_check(j)=Funcval;
		% 	end
		% 	Funcval_check
		% 	[val,minimum]=min(Funcval_check)
		% 	P=P_check(minimum,:);
		% end
		

		
		
		meshcompare(F,G)


		if count>1
			stop_check1=Funcval_store(count)/Funcval_store(count-1)<1.005;
			stop_check2=Funcval_store(count)/Funcval_store(count-1)>0.995;
		else
			stop_check2=0;
			stop_check1=0;
		end
		if (count>1000)||((count>2)&&((norm(stepChange)<0.000001)&&(Funcval<0.005)||(Funcval<0.001))||(stop_check1==1&&stop_check2==1&&Funcval<0.005&&count>3))%||((norm(stepChange)<0.000001))
			flag=1;
			P_final=P;
			% meshcompare(F,G)
			Corr_out=Funcval; 
			iterations=count;
		end
	end

end


function out=S2(F,Ftemp,dF,coef,P,subsize,dy,dx,X,Y)
	xp=zeros([subsize, subsize]);
	yp=zeros([subsize, subsize]);
	G=zeros([subsize, subsize]);
	numP=max(size(P));
	for i=1:subsize
		for j=1:subsize
			xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X(i,j);
			yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y(i,j);
		end
	end

	for i=1:subsize
		% fprintf('interp %d \n', i);
		for j=1:subsize
			a=reshape(coef(floor(yp(i,j)),floor(xp(i,j)),:),[4,4]);
			x_dec=mod(xp(i,j),1);
			y_dec=mod(yp(i,j),1);
			if numP==6
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3];
			elseif numP==7
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3]+P(7);
			elseif numP==8
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3].*P(8)+P(7);
			end
			% G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3];
			%% G(i,j)=[1, y_dec, y_dec^2, y_dec^3]*a*[1; x_dec; x_dec^2; x_dec^3];
		end
	end
	out=sum(sum((F-G).^2))/(sum(sum(F)));

	% Gmean=mean(mean(G));
	% Gtemp=G-ones([subsize, subsize])*Gmean;
	% dG_temp=sum(sum(Gtemp.^2));
	% dG=sqrt(dG_temp);
	% out=sum(sum((Ftemp./dF-Gtemp./dG).^2));


	% out=1-out1/2;
	% out=sum(sum((Ftemp-G).^2));
end

function out=CorVal(coef,P,dy,dx,X,Y,F)
	[r,c]=size(F);
	xp=zeros([r, c]);
	yp=zeros([r, c]);
	G=zeros([r, c]);
	numP=max(size(P));

	for i=1:r
		for j=1:c
			% xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X(i,j);
			% yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y(i,j);
			xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X;
			yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y;
		end
	end

	for i=1:r
		for j=1:c
			a=reshape(coef(floor(yp(i,j)),floor(xp(i,j)),:),[4,4]);
			x_dec=mod(xp(i,j),1);
			y_dec=mod(yp(i,j),1);
			if numP==6
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3];
			elseif numP==7
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3]+P(7);
			elseif numP==8
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3].*P(8)+P(7);
			end
		end
	end
	Fmean=mean(mean(F));
	Gmean=mean(mean(G));

	F2=sqrt(sum(sum(F.^2)));
	G2=sqrt(sum(sum(G.^2)));

	% Corr=sum(sum((F./F2-G./G2).^2));
	out=sum(sum(((F-Fmean)./F2-(G-Gmean)./G2).^2));
end

function out=CorVal2(F,G)

	Fmean=mean(mean(F));
	Gmean=mean(mean(G));

	% F2=sqrt(sum(sum(F.^2)));
	% G2=sqrt(sum(sum(G.^2)));

	% Corr=sum(sum((F./F2-G./G2).^2));
	out=sum(sum((F-Fmean - (G-Gmean)).^2));
	% out=sum(sum(((F-Fmean)./F2-(G-Gmean)./G2).^2));
end

function out=CorVal3(F,G)

	% Fmean=mean(mean(F));
	% Gmean=mean(mean(G));

	F2=sqrt(sum(sum(F.^2)));
	G2=sqrt(sum(sum(G.^2)));

	% Corr=sum(sum((F./F2-G./G2).^2));
	out=sum(sum((F./F2-G./G2).^2));
	% out=sum(sum(((F-Fmean)./F2-(G-Gmean)./G2).^2));
end


function [G,J,H,Corr]=getJac(coef,P,dy,dx,X,Y,F)
	% custom correlation coeficient that works for newton raphson
	[r,c]=size(F);
	Jcoef=-2/(sum(sum(F.^2)));
	xp=zeros([r, c]);
	yp=zeros([r, c]);
	G=zeros([r, c]);
	for i=1:r
		for j=1:c
			% xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X(i,j);
			% yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y(i,j);
			xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X;
			yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y;
		end
	end
	numP=max(size(P));
	J=zeros([numP,1]);
	H=zeros([numP,numP]);
	for i=1:r
		% fprintf('interp %d \n', i);
		for j=1:c
			% coef_out(i,j,:)=coef(floor(yp(i,j)),floor(xp(i,j)),:);
			a=reshape(coef(floor(yp(i,j)),floor(xp(i,j)),:),[4,4]);
			x_dec=mod(xp(i,j),1);
			y_dec=mod(yp(i,j),1);
			if numP==6
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3];
			elseif numP==7
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3]+P(7);
			elseif numP==8
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3].*P(8)+P(7);
			end
					
			% G(i,j)=[1, y_dec, y_dec^2, y_dec^3]*a*[1; x_dec; x_dec^2; x_dec^3];
			% Jacky=(JacobianValues(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			Jacky=(JacobianValues(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));
			% size(Jacky)
			% size(J)
			J=J+(F(i,j)-G(i,j)).*Jacky';
			H=H+Jacky'*Jacky;
		end
	end
	J=J.*Jcoef;
	H=-Jcoef*H;
	Corr=sum(sum((F-G).^2))/(sum(sum(F)));
	% Fmean=mean(mean(F))
	% Gmean=mean(mean(G))
	% out1=sum(sum((F-Fmean - (G-Gmean)).^2))
	% F2=sqrt(sum(sum(F.^2)));
	% G2=sqrt(sum(sum(G.^2)));
	% out2=sum(sum((F./F2-G./G2).^2))
	% actual_corr=sum(sum(((F-Fmean)./F2-(G-Gmean)./G2).^2))


	% meshcompare(G,F)
	% meshcompare(F,G)
	% max(max((G./F)))

	% figure
	% surf(G)
	% figure
	% surf(F)
end

function [G,J,H,Corr]=getJac2(coef,P,dy,dx,X,Y,F)
	% zero mean sum of squared difference
	[r,c]=size(F);
	Jcoef=-2/(sum(sum(F.^2)));
	xp=zeros([r, c]);
	yp=zeros([r, c]);
	G=zeros([r, c]);
	numP=max(size(P));

	for i=1:r
		for j=1:c
			% xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X(i,j);
			% yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y(i,j);
			xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X;
			yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y;
		end
	end

	% for i=1:r
	% 	for j=1:c
	% 		xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X(i,j);
	% 		yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y(i,j);
	% 	end
	% end
	for i=1:r
		for j=1:c
			a=reshape(coef(floor(yp(i,j)),floor(xp(i,j)),:),[4,4]);
			x_dec=mod(xp(i,j),1);
			y_dec=mod(yp(i,j),1);
			if numP==6
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3];
			elseif numP==7
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3]+P(7);
			elseif numP==8
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3].*P(8)+P(7);
			end
		end
	end
	Fmean=mean(mean(F));
	Gmean=mean(mean(G));

	
	
	J=zeros([numP,1]);
	H=zeros([numP,numP]);
	for i=1:r
		% fprintf('interp %d \n', i);
		for j=1:c
			% coef_out(i,j,:)=coef(floor(yp(i,j)),floor(xp(i,j)),:);

			% G(i,j)=[1, y_dec, y_dec^2, y_dec^3]*a*[1; x_dec; x_dec^2; x_dec^3];
			% Jacky=(JacobianValues(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			% % size(Jacky)
			% % size(J)
			% J=J+(F(i,j)-G(i,j)).*Jacky';
			% H=H+Jacky'*Jacky;

			% Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			% Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));
			Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));

			J=J+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Jacky');
			% check1=(-Jacky)'*(-Jacky)
			% check2=(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess)
			H=H+(-Jacky)'*(-Jacky)+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess);
		end
	end
	% J=J.*Jcoef;
	% H=-Jcoef*H;
	J=2*J;
	H=2*H;
	Corr=sum(sum((F-Fmean - (G-Gmean)).^2));
end

function [G,J,H,Corr]=getJac3(coef,P,dy,dx,X,Y,F)
	% normalised sum of squared difference
	[r,c]=size(F);
	Jcoef=-2/(sum(sum(F.^2)));
	xp=zeros([r, c]);
	yp=zeros([r, c]);
	G=zeros([r, c]);
	numP=max(size(P));

	for i=1:r
		for j=1:c
			% xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X(i,j);
			% yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y(i,j);
			xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X;
			yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y;
		end
	end

	% for i=1:r
	% 	for j=1:c
	% 		xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X(i,j);
	% 		yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y(i,j);
	% 	end
	% end
	for i=1:r
		for j=1:c
			a=reshape(coef(floor(yp(i,j)),floor(xp(i,j)),:),[4,4]);
			x_dec=mod(xp(i,j),1);
			y_dec=mod(yp(i,j),1);
			if numP==6
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3];
			elseif numP==7
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3]+P(7);
			elseif numP==8
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3].*P(8)+P(7);
			end
		end
	end
	% Fmean=mean(mean(F));
	% Gmean=mean(mean(G));

	F2=sqrt(sum(sum(F.^2)));
	G2=sqrt(sum(sum(G.^2)));

	
	
	J=zeros([numP,1]);
	H=zeros([numP,numP]);
	for i=1:r
		% fprintf('interp %d \n', i);
		for j=1:c

			% Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			% Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));
			Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));

			% J=J+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Jacky');
			J=J+(F(i,j)/F2-G(i,j)/G2).*(-Jacky'/G2);
			% check1=(-Jacky)'*(-Jacky)
			% check2=(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess)
			% H=H+(-Jacky)'*(-Jacky)+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess);
			H=H+(-Jacky')*(-Jacky) + (F(i,j)*G2/F2-G(i,j)).*(-Hess); %if transpose jacky outside of brackets it doesn't work

		end
	end
	% J=J.*Jcoef;
	% H=-Jcoef*H;
	J=2*J;
	H=2/(G2*G2)*H;
	Corr=sum(sum((F./F2-G./G2).^2));
end

function [G,J,H,Corr]=getJac4(coef,P,dy,dx,X,Y,F)
	% zero mean sum of squared difference
	[r,c]=size(F);
	Jcoef=-2/(sum(sum(F.^2)));
	xp=zeros([r, c]);
	yp=zeros([r, c]);
	G=zeros([r, c]);
	numP=max(size(P));

	for i=1:r
		for j=1:c
			% xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X(i,j);
			% yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y(i,j);
			xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X;
			yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y;
		end
	end

	% for i=1:r
	% 	for j=1:c
	% 		xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X(i,j);
	% 		yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y(i,j);
	% 	end
	% end
	for i=1:r
		for j=1:c
			a=reshape(coef(floor(yp(i,j)),floor(xp(i,j)),:),[4,4]);
			x_dec=mod(xp(i,j),1);
			y_dec=mod(yp(i,j),1);
			if numP==6
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3];
			elseif numP==7
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3]+P(7);
			elseif numP==8
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3].*P(8)+P(7);
			end
		end
	end
	Fmean=mean(mean(F));
	Gmean=mean(mean(G));

	JJ=zeros([numP,1]);
	HH=zeros([numP,numP]);

	for i=1:r
		for j=1:c


			% Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			% Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));
			Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));
			JJ=JJ+Jacky';
			HH=HH+Hess;
		end
	end
	JJ=JJ./(r*c);
	HH=HH./(r*c);
	
	
	J=zeros([numP,1]);
	H=zeros([numP,numP]);
	for i=1:r
		% fprintf('interp %d \n', i);
		for j=1:c
			% coef_out(i,j,:)=coef(floor(yp(i,j)),floor(xp(i,j)),:);

			% G(i,j)=[1, y_dec, y_dec^2, y_dec^3]*a*[1; x_dec; x_dec^2; x_dec^3];
			% Jacky=(JacobianValues(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			% % size(Jacky)
			% % size(J)
			% J=J+(F(i,j)-G(i,j)).*Jacky';
			% H=H+Jacky'*Jacky;

			% Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			% Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));

			Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));
			Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));

			J=J+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Jacky'+JJ);
			% check1=(-Jacky)'*(-Jacky)
			% check2=(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess)
			H=H+(-Jacky+JJ)'*(-Jacky+JJ)+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess+HH);
			% H=H+(-Jacky+JJ)'*(-Jacky+JJ);
		end
	end
	% J=J.*Jcoef;
	% H=-Jcoef*H;
	J=2*J;
	H=2*H;
	Corr=sum(sum((F-Fmean - (G-Gmean)).^2));
end

function [G,J,H,Corr]=getJac5(coef,P,dy,dx,X,Y,F)
	% zero-mean sum of squared difference
	[r,c]=size(F);
	xp=zeros([r, c]);
	yp=zeros([r, c]);
	G=zeros([r, c]);
	numP=max(size(P));

	for i=1:r
		for j=1:c
			% xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X(i,j);
			% yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y(i,j);
			xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X;
			yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y;
		end
	end

	for i=1:r
		for j=1:c
			a=reshape(coef(floor(yp(i,j)),floor(xp(i,j)),:),[4,4]);
			x_dec=mod(xp(i,j),1);
			y_dec=mod(yp(i,j),1);
			if numP==6
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3];
			elseif numP==7
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3]+P(7);
			elseif numP==8
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3].*P(8)+P(7);
			end
		end
	end
	Fmean=mean(mean(F));
	Gmean=mean(mean(G));
	
	J=zeros([numP,1]);
	H=zeros([numP,numP]);
	for i=1:r
		% fprintf('interp %d \n', i);
		for j=1:c

			% Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			% Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));
			Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));

			J=J+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Jacky');
			% J=J+(F(i,j)/F2-G(i,j)/G2).*(-Jacky'/G2);
			% check1=(-Jacky)'*(-Jacky)
			% check2=(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess)
			% H=H+(-Jacky)'*(-Jacky)+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess);
			H=H+(-Jacky')*(-Jacky)+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess); %if transpose jacky outside of brackets it doesn't work
			% H=H+(-Jacky)'*(-Jacky) + (F(i,j)*G2/F2-G(i,j)).*(-Hess);

		end
	end
	% J=J.*Jcoef;
	% H=-Jcoef*H;
	J=2*J;
	H=2*H;
	% Corr=sum(sum((F./F2-G./G2).^2));
	Corr=sum(sum((F-Fmean - (G-Gmean)).^2));
end

function [G,J,H,Corr]=getJac6(coef,P,dy,dx,X,Y,F)
	% normalised sum of squared difference
	[r,c]=size(F);
	Jcoef=-2/(sum(sum(F.^2)));
	xp=zeros([r, c]);
	yp=zeros([r, c]);
	G=zeros([r, c]);
	numP=max(size(P));

	for i=1:r
		for j=1:c
			% xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X(i,j);
			% yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y(i,j);
			xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X;
			yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y;
		end
	end

	% for i=1:r
	% 	for j=1:c
	% 		xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X(i,j);
	% 		yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y(i,j);
	% 	end
	% end
	for i=1:r
		for j=1:c
			a=reshape(coef(floor(yp(i,j)),floor(xp(i,j)),:),[4,4]);
			x_dec=mod(xp(i,j),1);
			y_dec=mod(yp(i,j),1);
			if numP==6
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3];
			elseif numP==7
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3]+P(7);
			elseif numP==8
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3].*P(8)+P(7);
			end
		end
	end
	% Fmean=mean(mean(F));
	% Gmean=mean(mean(G));

	F2=sqrt(sum(sum(F.^2)));
	G2=sqrt(sum(sum(G.^2)));

	
	
	J=zeros([numP,1]);
	H=zeros([numP,numP]);
	for i=1:r
		% fprintf('interp %d \n', i);
		for j=1:c

			% Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			% Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));
			Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));

			% J=J+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Jacky');
			J=J+(F(i,j)/F2-G(i,j)/G2).*((-Jacky')/G2);
			% check1=(-Jacky)'*(-Jacky)
			% check2=(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess)
			% H=H+(-Jacky)'*(-Jacky)+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess);
			H=H+(-Jacky'./G2)*(-Jacky./G2) + (F(i,j)/F2-G(i,j)/G2).*(-Hess)/G2; %if transpose jacky outside of brackets it doesn't work

		end
	end
	% J=J.*Jcoef;
	% H=-Jcoef*H;
	J=2*J;
	% H=2/(G2*G2)*H;
	H=2*H;
	Corr=sum(sum((F./F2-G./G2).^2));
end

function [G,J,H,Corr]=getJac7(coef,P,dy,dx,X,Y,F)
	% zero-mean sum of squared difference (full differentiation)
	[r,c]=size(F);
	xp=zeros([r, c]);
	yp=zeros([r, c]);
	G=zeros([r, c]);
	numP=max(size(P));

	for i=1:r
		for j=1:c
			% xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X(i,j);
			% yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y(i,j);
			xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X;
			yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y;
		end
	end

	for i=1:r
		for j=1:c
			a=reshape(coef(floor(yp(i,j)),floor(xp(i,j)),:),[4,4]);
			x_dec=mod(xp(i,j),1);
			y_dec=mod(yp(i,j),1);
			if numP==6
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3];
			elseif numP==7
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3]+P(7);
			elseif numP==8
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3].*P(8)+P(7);
			end
		end
	end
	Fmean=mean(mean(F));
	Gmean=mean(mean(G));
	Jmean=0;
	Hmean=0;
	for i=1:r
		for j=1:c
			Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));
			Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));
			Jmean=Jmean+Jacky';
			Hmean=Hmean+Hess;
		end
	end
	
	J=zeros([numP,1]);
	H=zeros([numP,numP]);
	for i=1:r
		% fprintf('interp %d \n', i);
		for j=1:c

			% Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			% Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));
			Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));

			J=J+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Jacky'+Jmean/(r*c));
			% J=J+(F(i,j)/F2-G(i,j)/G2).*(-Jacky'/G2);
			% check1=(-Jacky)'*(-Jacky)
			% check2=(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess)
			% H=H+(-Jacky)'*(-Jacky)+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess);
			H=H+(-Jacky'+Jmean/(r*c))*(-Jacky+Jmean'/(r*c))+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess+Hmean/(r*c)); %if transpose jacky outside of brackets it doesn't work
			% H=H+(-Jacky)'*(-Jacky) + (F(i,j)*G2/F2-G(i,j)).*(-Hess);

		end
	end
	% J=J.*Jcoef;
	% H=-Jcoef*H;
	J=2*J;
	H=2*H;
	% Corr=sum(sum((F./F2-G./G2).^2));
	Corr=sum(sum((F-Fmean - (G-Gmean)).^2));
end

function [G,J,H,Corr]=getJac8(coef,P,dy,dx,X,Y,F)
	% normalised cross correlation
	[r,c]=size(F);
	% Jcoef=-2/(sum(sum(F.^2)));
	xp=zeros([r, c]);
	yp=zeros([r, c]);
	G=zeros([r, c]);
	numP=max(size(P));

	for i=1:r
		for j=1:c
			% xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X(i,j);
			% yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y(i,j);
			xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X;
			yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y;
		end
	end

	% for i=1:r
	% 	for j=1:c
	% 		xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X(i,j);
	% 		yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y(i,j);
	% 	end
	% end
	for i=1:r
		for j=1:c
			a=reshape(coef(floor(yp(i,j)),floor(xp(i,j)),:),[4,4]);
			x_dec=mod(xp(i,j),1);
			y_dec=mod(yp(i,j),1);
			if numP==6
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3];
			elseif numP==7
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3]+P(7);
			elseif numP==8
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3].*P(8)+P(7);
			end
		end
	end
	% Fmean=mean(mean(F));
	% Gmean=mean(mean(G));

	% F2=sqrt(sum(sum(F.^2)));
	% G2=sqrt(sum(sum(G.^2)));
	bottom=sqrt(sum(sum(F.^2))*sum(sum(G.^2)));

	
	
	J=zeros([numP,1]);
	H=zeros([numP,numP]);
	for i=1:r
		% fprintf('interp %d \n', i);
		for j=1:c

			% Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			% Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));
			Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));

			J=J+F(i,j)*Jacky';
			H=H+F(i,j)*Hess;

			% J=J+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Jacky');
			% J=J+(F(i,j)/F2-G(i,j)/G2).*((-Jacky')/G2);
			% check1=(-Jacky)'*(-Jacky)
			% check2=(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess)
			% H=H+(-Jacky)'*(-Jacky)+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess);
			% H=H+(-Jacky'./G2)*(-Jacky./G2) + (F(i,j)/F2-G(i,j)/G2).*(-Hess)/G2; %if transpose jacky outside of brackets it doesn't work

		end
	end
	% J=J.*Jcoef;
	% H=-Jcoef*H;
	J=J/bottom;
	% H=2/(G2*G2)*H;
	H=H/bottom;
	Corr=2*(1-sum(sum((F*G).^2))/bottom);
end

function [G,J,H,Corr]=getJac6_2(coef,P,dy,dx,X,Y,F) % not working
	% normalised sum of squared difference
	[r,c]=size(F);
	Jcoef=-2/(sum(sum(F.^2)));
	xp=zeros([r, c]);
	yp=zeros([r, c]);
	G=zeros([r, c]);
	numP=max(size(P));

	for i=1:r
		for j=1:c
			% xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X;
			% yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y;
			xp(i,j)=P(1)+dx(i,j).*(1.0)+X;
			yp(i,j)=P(2)+dy(i,j).*(1.0)+Y;
		end
	end

	% for i=1:r
	% 	for j=1:c
	% 		xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X(i,j);
	% 		yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y(i,j);
	% 	end
	% end
	for i=1:r
		for j=1:c
			a=reshape(coef(floor(yp(i,j)),floor(xp(i,j)),:),[4,4]);
			x_dec=mod(xp(i,j),1);
			y_dec=mod(yp(i,j),1);
			if numP==6
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3];
			elseif numP==7
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3]+P(7);
			elseif numP==8
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3].*P(8)+P(7);
			end
		end
	end
	% Fmean=mean(mean(F));
	% Gmean=mean(mean(G));

	F2=sqrt(sum(sum(F.^2)));
	G2=sqrt(sum(sum(G.^2)));

	
	
	J=zeros([numP,1]);
	H=zeros([numP,numP]);
	for i=1:r
		% fprintf('interp %d \n', i);
		for j=1:c

			% Jacky=(JacobianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			% Hess=(HessianStandard(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X(i,j),Y(i,j)));
			Jacky=(JacobianStandard_p2(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));
			Hess=(HessianStandard_p2(coef(floor(yp(i,j)),floor(xp(i,j)),:),P',dx(i,j),dy(i,j),X,Y));

			% J=J+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Jacky');
			J=J+(F(i,j)/F2-G(i,j)/G2).*((-Jacky')/G2);
			% check1=(-Jacky)'*(-Jacky)
			% check2=(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess)
			% H=H+(-Jacky)'*(-Jacky)+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess);
			H=H+(-Jacky'./G2)*(-Jacky./G2) + (F(i,j)/F2-G(i,j)/G2).*(-Hess)/G2; %if transpose jacky outside of brackets it doesn't work

		end
	end
	% J=J.*Jcoef;
	% H=-Jcoef*H;
	J=2*J;
	% H=2/(G2*G2)*H;
	H=2*H;
	Corr=sum(sum((F./F2-G./G2).^2));
end

function varargout=getJac5_eff(coef,P,dy,dx,X,Y,F,choice,subpos,stepsize,coef_shift)
	% zero-mean sum of squared difference
	[r,c]=size(F);
	xp=zeros([r, c]);
	yp=zeros([r, c]);
	G=zeros([r, c]);
	numP=max(size(P));

	% determine the current position of the sample points according to the current estimates of the P parameters
	for i=1:r
		for j=1:c
			xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X;
			yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y;
		end
	end

	% determine the G values at the sample points using interpolation
	for i=1:r
		for j=1:c
			a=reshape(coef(floor(yp(i,j))-subpos.coords(1)+1+stepsize-coef_shift(1),floor(xp(i,j))-subpos.coords(2)+1+stepsize-coef_shift(2),:),[4,4]);
			x_dec=mod(xp(i,j),1);
			y_dec=mod(yp(i,j),1);
			if numP==6
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3];
			elseif numP==7
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3]+P(7);
			elseif numP==8
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3].*P(8)+P(7);
			end
		end
	end
	% determine the mean values for the reference and deformed subset
	Fmean=mean(mean(F));
	Gmean=mean(mean(G));
	if choice==1 % if want the correlation coefficient
		Corr=sum(sum((F-Fmean - (G-Gmean)).^2));
		varargout{1}=G;
		varargout{2}=Corr;
	elseif choice==2 % if want the Jacobian and Hessian matrices
		J=zeros([numP,1]);
		H=zeros([numP,numP]);
		for i=1:r
			for j=1:c
				Jacky=(JacobianStandard(coef(floor(yp(i,j))-subpos.coords(1)+1+stepsize,floor(xp(i,j))-subpos.coords(2)+1+stepsize,:),P',dx(i,j),dy(i,j),X,Y));
				Hess=(HessianStandard(coef(floor(yp(i,j))-subpos.coords(1)+1+stepsize,floor(xp(i,j))-subpos.coords(2)+1+stepsize,:),P',dx(i,j),dy(i,j),X,Y));

				J=J+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Jacky');

				H=H+(-Jacky')*(-Jacky)+(F(i,j)-Fmean - (G(i,j)-Gmean)).*(-Hess); %if transpose jacky outside of brackets it doesn't work
			end
		end
		J=2*J;
		H=2*H;
		varargout{1}=G;
		varargout{2}=J;
		varargout{3}=H;
	end
end

function varargout=getJac6_eff(coef,P,dy,dx,X,Y,F,choice,subpos,stepsize,coef_shift)
	% normalised sum of squared difference
	[r,c]=size(F);
	xp=zeros([r, c]);
	yp=zeros([r, c]);
	G=zeros([r, c]);
	numP=max(size(P));

	% determine the current position of the sample points according to the current estimates of the P parameters
	for i=1:r
		for j=1:c
			xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X;
			yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y;
		end
	end

	% determine the G values at the sample points using interpolation
	for i=1:r
		for j=1:c
			a=reshape(coef(floor(yp(i,j))-subpos.coords(1)+1+stepsize-coef_shift(1),floor(xp(i,j))-subpos.coords(2)+1+stepsize-coef_shift(2),:),[4,4]);
			x_dec=mod(xp(i,j),1);
			y_dec=mod(yp(i,j),1);
			if numP==6
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3];
			elseif numP==7
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3]+P(7);
			elseif numP==8
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3].*P(8)+P(7);
			end
		end
	end
	% determine the needed constants for the reference and deformed subset
	F2=sqrt(sum(sum(F.^2)));
	G2=sqrt(sum(sum(G.^2)));
	if choice==1 % if want the correlation coefficient
		Corr=sum(sum((F./F2-G./G2).^2));
		varargout{1}=G;
		varargout{2}=Corr;
	elseif choice==2 % if want the Jacobian and Hessian matrices
		J=zeros([numP,1]);
		H=zeros([numP,numP]);
		for i=1:r
			for j=1:c
				Jacky=(JacobianStandard(coef(floor(yp(i,j))-subpos.coords(1)+1+stepsize,floor(xp(i,j))-subpos.coords(2)+1+stepsize,:),P',dx(i,j),dy(i,j),X,Y));
				Hess=(HessianStandard(coef(floor(yp(i,j))-subpos.coords(1)+1+stepsize,floor(xp(i,j))-subpos.coords(2)+1+stepsize,:),P',dx(i,j),dy(i,j),X,Y));

				J=J+(F(i,j)/F2-G(i,j)/G2).*((-Jacky')/G2);
				H=H+(-Jacky'./G2)*(-Jacky./G2) + (F(i,j)/F2-G(i,j)/G2).*(-Hess)/G2; %if transpose jacky outside of brackets it doesn't work
			end
		end
		J=2*J;
		H=2*H;
		varargout{1}=G;
		varargout{2}=J;
		varargout{3}=H;
	end
end

function varargout=getJac1_eff(coef,P,dy,dx,X,Y,F,choice,subpos,stepsize,coef_shift)
	% zero-mean normalised sum of squared difference
	[r,c]=size(F);
	xp=zeros([r, c]);
	yp=zeros([r, c]);
	G=zeros([r, c]);
	numP=max(size(P));

	% determine the current position of the sample points according to the current estimates of the P parameters
	for i=1:r
		for j=1:c
			xp(i,j)=P(1)+P(3).*dy(i,j)+dx(i,j).*(P(2)+1.0)+X;
			yp(i,j)=P(4)+P(5).*dx(i,j)+dy(i,j).*(P(6)+1.0)+Y;
		end
	end

	% determine the G values at the sample points using interpolation
	for i=1:r
		for j=1:c
			% used=[floor(yp(i,j)),floor(xp(i,j))]
			a=reshape(coef(floor(yp(i,j))-subpos.coords(1)+1+stepsize*coef_shift(3)-coef_shift(1),floor(xp(i,j))-subpos.coords(2)+1+stepsize*coef_shift(3)-coef_shift(2),:),[4,4]);
			x_dec=mod(xp(i,j),1);
			y_dec=mod(yp(i,j),1);
			if numP==6
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3];
			elseif numP==7
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3]+P(7);
			elseif numP==8
				G(i,j)=[1, x_dec, x_dec^2, x_dec^3]*a*[1; y_dec; y_dec^2; y_dec^3].*P(8)+P(7);
			end
		end
	end
	% determine the needed constants for the reference and deformed subset
	Fmean=mean(mean(F));
	Gmean=mean(mean(G));
	F2=sqrt(sum(sum((F-Fmean).^2)));
	G2=sqrt(sum(sum((G-Gmean).^2)));
	if choice==1 % if want the correlation coefficient
		% Corr=0;
		% for i=1:r
		% 	for j=1:c
		% 		Corr=Corr+((F(i,j)-Fmean)/F2-(G(i,j)-Gmean)/G2).^2;
		% 	end
		% end
		Corr=sum(sum(((F-Fmean)./F2-(G-Gmean)./G2).^2));
		varargout{1}=G;
		varargout{2}=Corr;
	elseif choice==2 % if want the Jacobian and Hessian matrices
		J=zeros([numP,1]);
		H=zeros([numP,numP]);
		for i=1:r
			for j=1:c
				Jacky=(JacobianStandard(coef(floor(yp(i,j))-subpos.coords(1)+1+stepsize*coef_shift(3),floor(xp(i,j))-subpos.coords(2)+1+stepsize*coef_shift(3),:),P',dx(i,j),dy(i,j),X,Y));
				Hess=(HessianStandard(coef(floor(yp(i,j))-subpos.coords(1)+1+stepsize*coef_shift(3),floor(xp(i,j))-subpos.coords(2)+1+stepsize*coef_shift(3),:),P',dx(i,j),dy(i,j),X,Y));

				J=J+((F(i,j)-Fmean)/F2-(G(i,j)-Gmean)/G2).*((-Jacky')./G2);
				H=H+(-Jacky'./G2)*(-Jacky./G2) + ((F(i,j)-Fmean)/F2-(G(i,j)-Gmean)/G2).*(-Hess)./G2; %if transpose jacky outside of brackets it doesn't work
			end
		end
		J=2*J;
		H=2*H;
		varargout{1}=G;
		varargout{2}=J;
		varargout{3}=H;
	end
end