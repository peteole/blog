Point(1) = {0.0, 0.0, 0.0,0.005};
Point(2) = {0.1, 0.046561895043862704, 0.0,0.005};
Point(3) = {0.2, 0.056968557150769476, 0.0,0.005};
Point(4) = {0.3, 0.05948422462775665, 0.0,0.005};
Point(5) = {0.4, 0.05738266105317275, 0.0,0.005};
Point(6) = {0.5, 0.05219019673131475, 0.0,0.005};
Point(7) = {0.6, 0.04479110070446828, 0.0,0.005};
Point(8) = {0.7, 0.03570927685952479, 0.0,0.005};
Point(9) = {0.8, 0.025211311562171167, 0.0,0.005};
Point(10) = {0.9, 0.013352458679209828, 0.0,0.005};
Point(11) = {1.0, 1.650594053104193e-17, 0.0,0.005};
Point(12) = {0.9, -0.013352458679209828, 0.0,0.005};
Point(13) = {0.8, -0.025211311562171167, 0.0,0.005};
Point(14) = {0.7, -0.03570927685952479, 0.0,0.005};
Point(15) = {0.6, -0.04479110070446828, 0.0,0.005};
Point(16) = {0.5, -0.05219019673131475, 0.0,0.005};
Point(17) = {0.4, -0.05738266105317275, 0.0,0.005};
Point(18) = {0.30000000000000004, -0.05948422462775666, 0.0,0.005};
Point(19) = {0.19999999999999996, -0.05696855715076947, 0.0,0.005};
Point(20) = {0.09999999999999998, -0.046561895043862704, 0.0,0.005};
Spline(1)={1:20,1};
Point(21) = {0.0, 5.0, 0.0, 0.3};
Point(22) = {0.0, -5.0, 0.0, 0.3};
Point(23) = {-5.0, 0.0, 0.0, 0.3};
Point(24) = {5.0, 5.0, 0.0, 0.3};
Point(25) = {5.0, -5.0, 0.0, 0.3};
Circle(21)= {22, 1, 23};
Circle(22)= {23, 1, 21};
Line(23) = {21, 24};
Line(24) = {24, 25};
Line(25) = {25, 22};
Curve Loop(2) = {21:25};
Curve Loop(3) = {1};
Plane Surface(1) = {2,3};