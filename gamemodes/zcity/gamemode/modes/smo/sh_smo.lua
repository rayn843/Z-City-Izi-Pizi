local MODE = MODE
zb = zb or {}
zb.Points = zb.Points or {}

-- Точки спавна команд и точек захвата для админского редактора точек (zb.DrawPoints)
zb.Points.HMCD_SWO_WAGNER = zb.Points.HMCD_SWO_WAGNER or {}
zb.Points.HMCD_SWO_WAGNER.Color = Color(25,95,0)   -- Wagner / RF (зелёный)
zb.Points.HMCD_SWO_WAGNER.Name = "HMCD_SWO_WAGNER"

zb.Points.HMCD_SWO_AZOV = zb.Points.HMCD_SWO_AZOV or {}
zb.Points.HMCD_SWO_AZOV.Color = Color(100,75,0)    -- Azov / UA (коричневый)
zb.Points.HMCD_SWO_AZOV.Name = "HMCD_SWO_AZOV"

zb.Points.HMCD_SWO_CAPPOINT = zb.Points.HMCD_SWO_CAPPOINT or {}
zb.Points.HMCD_SWO_CAPPOINT.Color = Color(220,180,0) -- точки захвата — контрастный жёлтый
zb.Points.HMCD_SWO_CAPPOINT.Name = "HMCD_SWO_CAPPOINT"

-- Точки спавна машин для SMO / Battlefield-режима
zb.Points.HMCD_SWO_CAR = zb.Points.HMCD_SWO_CAR or {}
zb.Points.HMCD_SWO_CAR.Color = Color(0, 170, 255) -- нейтральные машины
zb.Points.HMCD_SWO_CAR.Name = "HMCD_SWO_CAR"

-- Опционально: командные машины RU
zb.Points.HMCD_SWO_CAR_RU = zb.Points.HMCD_SWO_CAR_RU or {}
zb.Points.HMCD_SWO_CAR_RU.Color = Color(25, 95, 0)
zb.Points.HMCD_SWO_CAR_RU.Name = "HMCD_SWO_CAR_RU"

-- Опционально: командные машины UA
zb.Points.HMCD_SWO_CAR_UA = zb.Points.HMCD_SWO_CAR_UA or {}
zb.Points.HMCD_SWO_CAR_UA.Color = Color(100, 75, 0)
zb.Points.HMCD_SWO_CAR_UA.Name = "HMCD_SWO_CAR_UA"