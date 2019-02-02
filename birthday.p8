pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

_version = 0.3
actors = {} -- all active actors
presents = {} -- all active presents
grass_pattern = {} -- randomized grass pattern
static_animals = {'cat_left', 'cat_right', 'bird', 'racoon'}
presents_timer = 3*30 -- intial delay in seconds between presents spawn
score = 0
lives = 3
max_lives = 3
dog_chase_speed = 1.1 -- initial dog chase speed. this increses as score goes up
died = false -- used to decide which screen to show on start
playing = false -- is in active game or not
scroll_timer = 0
global_timer = 0

function analog_x()
-- returns values from -50 to 50 for mobile "analog stick control"
-- -50 stick is all the way left
-- 50 stick is all the way right 
    if(peek(0x5f81)==0) then return 0 
    else
        return peek(0x5f81) - 100 
    end
end

function make_actor(start_x)
    local a = {}
    a.x = start_x
    a.y = 112
    a.dx = 0
    a.dy = 0
    -- some sprites use a different color for transparency
    a.is_black_transparent = true
    add(actors, a)
    return a
end

function make_present(x, y, gravity)
    local p = {}
    p.x = x
    p.gravity = gravity
    p.y = y
    p.dy = 0
    add(presents, p)
    return p
end

function _init()
    pl = make_actor(60)
    pl.type = 'player'
    pl.start_spr = 1
    pl.frames = 2
    pl.cur_frame = 1
    pl.direction = 1

    dog = make_actor(50)
    dog.type = 'dog'
    dog.start_spr = 17
    dog.frames = 2
    dog.cur_frame = 1
    dog.t = 0
    dog.dir = 1
    dog.chase = false

    cat1 = make_actor(113)
    cat1.type = 'cat_left'
    cat1.y = 28
    cat1.start_spr = 104
    cat1.frames = 4
    cat1.cur_frame = 1
    cat1.animating = false

    cat2 = make_actor(6)
    cat2.type = 'cat_right'
    cat2.y = 28
    cat2.start_spr = 120
    cat2.frames = 4
    cat2.cur_frame = 1
    cat2.animating = false

    bird = make_actor(39)
    bird.type = 'bird'
    bird.y = 75
    bird.start_spr = 88
    bird.frames = 4
    bird.cur_frame = 1
    bird.animating = false

    racoon = make_actor(80)
    racoon.type = 'racoon'
    racoon.y = 75
    racoon.start_spr = 72
    racoon.frames = 4
    racoon.cur_frame = 1
    racoon.is_black_transparent = false
    racoon.animating = false

    for i=0,15 do
        add(grass_pattern, flr(rnd(2)))
    end

    music(10, 0, 3)
end

function on_the_ground(x, y)
    v = mget(flr(x+4)/8, flr(y)/8+1)
    return fget(v, 0)
end

function move_player(actor)
    local btn_pressed = false
    local ddx = 0
    if (btn(0)) or analog_x() < 0 then
        actor.start_spr = 3
        actor.cur_frame += 0.3
        ddx -= 0.25 - (analog_x() / 500)
        btn_pressed = true
    end

    if (btn(1)) or analog_x() > 0 then
         actor.start_spr = 1
        actor.cur_frame += 0.3
        ddx += 0.25 + (analog_x() / 500)
        btn_pressed = true
    end

    --limit max speed
    if actor.dx > 1.3 then
        actor.dx = 1.3
    elseif actor.dx < -1.3 then
        actor.dx = -1.3
    end

    -- drag
    if ddx == 0 then
        actor.dx *= 0.8
    end

    actor.y += actor.dy
    actor.dx += ddx
    actor.x += actor.dx

    -- gravity has to be applied after actor.y has been adjusted
    if on_the_ground(actor.x, actor.y) then
        actor.dy = 0
        actor.y = flr(flr(actor.y)/8)*8
    else
        actor.dy += 0.71

    end

    -- jump
    if btnp(5) then actor.dy = -4 end

    if flr(actor.cur_frame) > actor.frames  then actor.cur_frame = 1 end
    if not btn_pressed and flr(actor.cur_frame) > 1 then actor.cur_frame = 1 end
    if got_present(actor) then
        score += 1
        sfx(11)
        -- every 10 points make things harder, but replenish one heart
        if score%10 == 0 then
            lives += 1
            lives = min(lives, max_lives)
            dog_chase_speed += 0.1
            sfx(13)
        end

    end
    if actor.x > 120 then actor.x = 120 end
    if actor.x < 0 then actor.x = 0 end
end

function move_dog(dog)
    local speed = 0.3
    if #presents > 0 and not dog.chase then
        p = find_closest_present(dog.x)
        dog.chase = true
        dog.chase_p = p
        if dog.x > p.x and dog.dir == 1 then dog.dir = -1 end
        if dog.x < p.x and dog.dir == -1 then dog.dir = 1 end
    end

    if #presents == 0 then dog.chase = false end

    if dog.chase then
        if abs(dog.x - dog.chase_p.x) < 4 then
            speed = 0
            dog.cur_frame = 1
        else
            speed = dog_chase_speed
            dog.cur_frame += 0.5
        end
        dog.x += speed*dog.dir
    end

    -- move dog randomly if not chasing
    if not dog.chase then
        if dog.t < 60 then
            dog.x += speed*dog.dir
            dog.cur_frame += 0.5
        else
            if rnd(10) < 5 then dog.dir *= -1 end
            dog.t = 0
        end
    end

    dog.t += 1
    if dog.x > 120 or dog.x < 1 then dog.dir *= -1 end
    if flr(dog.cur_frame) > dog.frames  then dog.cur_frame = 1 end
    if dog.dir == -1 then
        dog.start_spr = 19
    else
        dog.start_spr = 17
    end
    if got_present(dog) then
        sfx(15)
        lives -= 1
        dog.chase = false
    end
end

function choose_animation()
    for a in all(static_animals) do
        for i in all(actors) do
            if i.type == a and i.animating == true then return true end -- somthing is already animating
        end
    end
    index  = flr(rnd(4)) + 1 -- choose a random static animal
    for i in all(actors) do
        if i.type == static_animals[index] then i.animating = true end
    end
end

function animate_static(actor)
    if actor.animating then 
        if global_timer%7 == 0 then actor.cur_frame += 1 end
        if actor.cur_frame > actor.frames then 
            actor.cur_frame = 1 
            actor.animating = false
        end
    end
end

function move_actor(actor)
    if actor.type == 'player' then move_player(actor) end
    if actor.type == 'dog' then move_dog(actor) end
    if actor.type == 'racoon' or actor.type == 'cat_left' or actor.type == 'cat_right' or actor.type == 'bird' then animate_static(actor) end
 end

function add_present()
    if presents_timer == 0 then
        local lane = flr(rnd(4))
        if lane == 0 then make_present(6, 36, 0.07) end
        if lane == 1 then make_present(113, 36, 0.07) end
        if lane == 2 then make_present(39, 83, 0.07) end
        if lane == 3 then make_present(80, 83, 0.07) end
        sfx(17)
        presents_timer = (flr(rnd(6))+2)*30 -- delay in seconds
    end
    presents_timer -= 1
end

function move_present(p)
    p.y += p.dy

    if on_the_ground(p.x, p.y) then
        p.dy = 0
        p.y = flr(flr(p.y)/8)*8
    else
        p.dy += p.gravity
    end
end

function got_present(actor)
    local ax = actor.x  + 4
    local ay = actor.y + 4
    for p in all(presents) do
        local px = p.x + 4
        local py = p.y + 4
        if abs(ax - px) < 8 and abs(ay - py) < 8 then
            del(presents, p)
            return true
        end
    end
    return false
end

function find_closest_present(x)
    min_dist = abs(presents[1].x - x)
    local i = 1
    for p in all(presents) do
        if abs(p.x - x) > min_dist then i += 1 end
    end
    return presents[i]
end

function draw_actor(actor)
    if actor.is_black_transparent then
        palt(14, false)
        palt(0, true)
    else
        palt(14, true)
        palt(0, false)
    end

    spr(actor.start_spr + flr(actor.cur_frame-1), actor.x, actor.y)
    --revert transparency back
    palt(14, false)
    palt(0, true)
end

function draw_present(p)
    spr(34, p.x, p.y)
end

function draw_lives()
    for i=1, max_lives do
        if i<= lives then
            spr(69, 90+i*8, 1)
        else
            spr(68, 90+i*8, 1)
        end
    end
end

function draw_grass()
    local x = 0
    for i in all(grass_pattern) do
        spr(49+i, x*8, 112)
        x += 1
     end
end

function _update()
    if playing then
        if lives == 0 then out_game() end
        add_present()
        foreach(actors, move_actor)
        foreach(presents, move_present)
        choose_animation()
        global_timer += 1
     else
        if btnp(5) then
            playing = true
            music(4, 0, 3)
            died = false
            lives = 3
            score = 0
            global_timer = 0
        end
     end

end

function _draw()
    if playing then
        rectfill(0,0,128,128,12)
        palt(14, true)
        palt(0, false)
        map(0,0,0,0,16,16)
        palt(0, true)
        palt(14, false)
        draw_grass()
        foreach(actors, draw_actor)
        foreach(presents, draw_present)
        draw_lives()
        print("score:"..score, 1,1,7)
        --print("lives:"..lives, 80,0,7)
    else
        if died then
            print("total score:"..score, 30, 50, 7)
            print("press x to restart", 30, 59, 7)
        else
            cls()
            rectfill(0,0,128,128,12)
            map(2, 18, 50,40, 5, 5)
            print("marina's birthday adventure", 10, 10, 3)
            print("use arrow keys to move around. use x to jump. music by gruber99.bandcamp.com", 128-scroll_timer, 22, 3)
            print("press x to start", 35, 110, 3)
            print("version: ".._version, 79, 120)
            scroll_timer += 1
            if scroll_timer > 500 then scroll_timer = 0 end
        end
     end


end

function out_game()
    -- borrowed from pico-9 Jelpi demo
    music(-1)
    sfx(-1)
    sfx(5)

    dpal={0,1,1, 2,1,13,6,
          4,4,9,3, 13,1,13,14}

    -- palette fade
    for i=0,40 do
        for j=1,15 do
            col = j
            for k=1,((i+(j%5))/4) do
                col=dpal[col]
            end
            pal(j,col,1)
        end
        flip()
    end
    -- restart cart end of slice
    died = true
    playing = false
    pal()
    cls()
end



__gfx__
000000000000000000000000000000000000000077555555555555777777777777777777777777775111111111111115777766777777777700000000eeddddde
000000000888880008888800008888800088888077555555555555775555555555555577766666675111111111111115777766777777777700000000eddddddd
007007008888f8808888f880088f8888088f8888775555555555557755555555555555777677776751000000000000157766667766677777cc000000ed00d00d
000770008f3ff3808f3ff380083ff3f8083ff3f87755555555555577555555555555557776777767510000000000001566666777666667779ccccccced00d00d
0007700088ffff8088ffff8008ffff8808ffff8877555555555555775555555555555577767667675100000000000015666777777766667707777cc0eddddddd
0070070088ccc80088ccc800008ccc88008ccc8877555555555555775555555555555577767667675105555005555015777777777777667700777700eed777de
00000000001110000011120000011100002111007755555555555577555555555555557776766767510500500500501566666666777766770000e000d0d777de
0000000000202000002000000002020000000200775555555555557755555555555555777676676751050050050050155555555577776677000eee00d0d0ddde
577777770000000000000000000000000000000000000000000000000000000077777777767667675105555005555015777777775555777777775555eeddddde
5777777700000000000000000000000000000000000000000000000000000000775555557676676751000000000000157777777755557cc77cc75555eddddddd
57ccc7cc00000000000000000000000000000000000000000000000000000000775555557676676751055550055550157777766655557cc77cc75555ed07d70d
57ccc7cc0000090000000900009000000090000000000090090000000000000077555555767667675105995005005015777666665555777777775555ed00d00d
57ccc7cc00000990000009900990000009900000000009900990000000000000775555557676676751059950050050157766667755557cc77cc75555eddddddd
5777777799999770999997700779999907799999999997700779999900000000775555557676676751055550055550157766777755557cc77cc75555eed777de
57ccc7cc0999999009999990099999900999999009999990099999900000000077555555767667675100000000000015776677775555777777775555d0d777de
57ccc7cc07000070700000070700007070000007070000700700007000000000775555557676676751055550055550157766777755557cc77cc75555d0d0ddde
57ccc7cc4444494400000000555555557777777777777775eeeeee5555eeeeee1111111176766767510500500500501577777777555555555555555555557c66
57777777494444940e000e00555555557777777777777775eeeee551155eeeee11111111767667675105005005005015777777d0555555555555555555557667
57ccc7cc9449444400e0e0005555555577ccc7ccc7ccc775eeee55111155eeee11111111767667675105555005555015777777d0555555555555555555556677
57ccc7cc444449440aaeaa005555555577ccc7ccc7ccc775eee5511111155eee1111111176766767510000000000001577777777555555555555555555566777
57ccc7cc444494440aaeaa005555555577ccc7ccc7ccc775ee555555111155ee1111111176766767511111111111111577777777555555555555555555667777
57ccc7cc494444940eeeee00555555557777777777777775e55155551555555e1111111176777767544444444444444577777777555555555555555556677777
57777777449494490aaeaa005555555577ccc7ccc7ccc77555111551155551551111111176777767444444444444444477777777555555555555555566777777
57777777444444440aaeaa005555555577ccc7ccc7ccc77555111111115511551111111176666667444444444444444477777777555555555555555567777777
0000000000000000000000007777777777ccc7ccc7ccc7755555556666555555555555666655555577667777cccccccc5555555500d00d000090090066c75555
0000000000000000000000007777777777777777777777755555566776655555555556677665555577667777cccccccc5555555500dddd000099990076675555
0000000000000000000000007777777777ccc7ccc7ccc7755555667777665555555566777766555577666777cccccccc55115511d0dddd000099990977665555
000e000000000000000000007777777777ccc7ccc7ccc7755556677777766555555667777776655577766666cccccccc55115511d00dd0000009900977766555
00e9e000000000000a0000007777777777ccc7ccc7ccc7755566777777776655556677777777665577777666cccccccc11551155d0dddd000099990977776655
000e000000000b00a8a000007777777777ccc7ccc7ccc7755667777777777665566666666666666577777777cccccccc11551155ddddddd00999999977777665
0003b003030003030a0000307777777777777777777777756677777777777766555555555555555566666666cccccccc551155110dddddd00999999077777766
3003003033030303030303307777777777777777777777756777777777777776555555555555555555555555cccccccc5511551100dddd000099990077777776
0000000022220000000000000000000008808800088088000000000000000000eedddddeeedddddeeedddddeeeddddde00000000000000000000000000000000
00000000222200000ee000ee0000000080080080888888800000000000000000edddddddedddddddedddddddeddddddd00000000000000000000000000000000
0000000022220200e00e0e00e000000080000080888888800000000000000000ed07d70ded00d00ded00d00ded70d70d00000000000000000000000000000000
00000000222220000eee0eee0000000008000800088888000000000000000000ed00d00ded07d07ded70d70ded00d00d00000000000000000000000000000000
00000000222220000000e0000000000000808000008880000000000000000000edddddddedddddddedddddddeddddddd00000000000000000000000000000000
0000000022224244aaaaeaaa0000000000080000000800000000000000000000eed777deeed777deeed777deeed777de00000000000000000000000000000000
0000000022224444aaaaeaaa0000000000000000000000000000000000000000d0d777ded0d777ded0d777ded0d777de00000000000000000000000000000000
0000000022224444aaaaeaaa0000000000000000000000000000000000000000d0d0ddded0d0ddded0d0ddded0d0ddde00000000000000000000000000000000
00000000999d9999aaaaeaaa000000001155115511115555111155110000000000000000000000c0000000000000000000000000000000000000000000000000
00000000999d9999aaaaeaaa00000000115511551111555511115551000000000000000000000c0000000cc00000000000000000000000000000000000000000
00000000999d9999aaaaeaaa0000000055115511555515515555155100000000cc000000cc00cc00cc00cc00cc00cccc00000000000000000000000000000000
00000000999d9999aaaaeaaa00000000551155115555111155551111000000009ccccccc9ccccccc9ccccccc9ccccccc00000000000000000000000000000000
00000000dddddddd11161111000000001155115515515555155155550000000007777cc007777cc007777cc007777cc000000000000000000000000000000000
00000000999d99991116111100000000115511551111555511115555000000000077770000777700007777000077770000000000000000000000000000000000
00000000999d99996666666600000000551155111111155111111551000000000000e0000000e0000000e0000000e00000000000000000000000000000000000
00000000999d9999111611110000000055115511111111111111111100000000000eee00000eee00000eee00000eee0000000000000000000000000000000000
000000000333333ee3333333000000005555555555555555000000000000000000d00d0000d0d00000d00d0000d00d0000000000000000000000000000000000
000000000333333ee3333333000000005555155555515555000000000000000000dddd0000dddd0000dddd0000dddd0000000000000000000000000000000000
000000000333333ee33333330000000055511155551115550000000000000000d0dddd00d0dddd0000dddd0000dddd0000000000000000000000000000000000
00000000ffeeeeeeeeeeeeeff0000000551a1a1551a1a1550000000000000000d00dd000d00dd000d00dd000000dd00000000000000000000000000000000000
0000000ffeeeeeeeeeeeeeeeff000000551a1a1551a1a1550000000000000000d0dddd00d0dddd00d0dddd00d0dddd0000000000000000000000000000000000
0000000fff33333ee333333fff00000055191915519191550000000000000000ddddddd0ddddddd0ddddddd0ddddddd000000000000000000000000000000000
0000000ffff3333ee33333ffff000000555111555511155500000000000000000dddddd00dddddd00dddddd00dddddd000000000000000000000000000000000
00000000ff33333ee333333ff00000005555555555555555000000000000000000dddd0000dddd0000dddd0000dddd0000000000000000000000000000000000
0ee0ee00000000220022000000000000000000000000000000000000000000000090090000090900009009000090090000000000000000000000000000000000
000e0000000000220022000000000000000000000000000000000000000000000099990000999900009999000099990000000000000000000000000000000000
111e1110000000220022000000000000000000000000000000000000000000000099990900999909009999000099990000000000000000000000000000000000
111e1110000000220022000000000000000000000000000000000000000000000009900900099009000990090009900000000000000000000000000000000000
111e1110000000880088000000000000000000000000000000000000000000000099990900999909009999090099990900000000000000000000000000000000
111e1110000088880088880000000000000000000000000000000000000000000999999909999999099999990999999900000000000000000000000000000000
111e1110008888880088888800000000000000000000000000000000000000000999999009999990099999900999999000000000000000000000000000000000
111e1110008888080080888800000000000000000000000000000000000000000099990000999900009999000099990000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000026555555555556270000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000002655555555555555562700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000265555555555555555555627000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0026555555555555555555555556270000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0018070707070707070707070707080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0005232323232323232323232323060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000524252425231d1e2324252425060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000534353435232f3f2334353435060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000523232323361c0d3723232323060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000523232338333a0c2c39232323060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0005242524250965640910252425060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000534353435190a0b1920353435060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000523232323191a1b1923232323060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000523232323292a2b2923232323060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212121212121212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4646464646464646460000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000460000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000004142430000460000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000005152000000460000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000606162630000460000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000707172000046460000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000046460000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
01030000185701c5701f57024570185701c5701f57024560185601c5601f56024560185501c5501f550245501a5501d5501f540245401a5301d5301f530235301a5301d5301f5301a5201d510215102451023515
01100000240452400528005280452b0450c005280450000529045240052d04500005300553c0252d005130052b0451f005260352b025260450c0052404500005230450c00521045230451f0450c0051c0451c005
01100000187451a7001c7001c7451d745187001c7451f7001a745247001d7451d70021745277002470023745217451f7001d7001d7451a7451b7001c7451f7001a745227001c7451b70018745187001f7451f700
01100000305453c52500600006003e625006000c30318600355250050000600006003e625006000060018600295263251529515006003e625006000060018600305250050018601006003e625246040060000600
01100000004750c47518475004750a475004750a4750c475004750a4750c475004750a4750c4751147513475004750c4750a475004750a475004750a4750c475004750c47516475004751647518475114750c475
01100000180721a0751b0721f0721e0751f0751e0721f075270752607724075200721f0751b0771a0751b07518072180621805218042180350000000000000000000000000000000000000000000000000000000
011000000c37518375243751f3751b3721a372193711b372183721837217371163511533114311133001830214302143021830218302003000030000300003000030000300003000030000300003000030000300
011000000c37300300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
000000001e0701f070220702a020340103f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002b7602e7503a73033740377302e75033730337303372035710377103a710337103a7103c7103c7003f700007000070000700007000070000700007000070000700007000070000700007000070000700
00020000276701d65013650106600c6400e63022620116300b63004630026101b6100861003610076101260013600106000d60010600116000e6001160012600116000a600066000960003600026000260002600
000100002257524575275652455527555275552b54524525225352252527525275252b5252e515305152e515305052e505305052e5053050530505335052b5052e5052b5052e5052e5053350530505335052e505
000200002005325043160231002304013030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102000013571165731b5751d5711157313575165711b5731b575225711b573185751b5711f573245751b5711f57324565295611f563185611d555245532b5552b5412b5433053137535335333a5212b5252e513
000200002b071270711b07118071100710b0710607104071040610606103061040510305101041010310102101011040110000000000000000000000000000000000000000000000000000000000000000000000
010200002e17029170171731a171231631d16111143141610c1230a11107110001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
01040000185702257024570225701f5701d5701f5701d57018570165701857016570135701157013570115700c5700d570135701457018560195501f550205302453024520225202452022510245102251024500
011000002415323153211531f1531d153001030010300103001030010300103001030010300103001030010300103001030010300103001030010300103001030010300103001030010300103001030010300103
0110000000140021000413002100021000210002140021000413002100001400210002100021000213002100001400210004130021000210002100021400210004130040500014000000021000b0000210010000
011600000042500415094250a4250042500415094250a42500425094253f2050a42508425094250a425074250c4250a42503425004150c4250a42503425004150c42500415186150042502425024250342504425
011600000c0330c4130f54510545186150c0330f545105450c0330f5450c41310545115450f545105450c0230c0330c4131554516545186150c03315545165450c0330c5450f4130f4130e5450e5450f54510545
0116000005425054150e4250f42505425054150e4250f425054250e4253f2050f4250d4250e4250f4250c4250a4250a42513425144150a4250a42513425144150a42509415086150741007410074120441101411
011600000c0330c4131454515545186150c03314545155450c033145450c413155451654514545155450c0230c0330c413195451a545186150c033195451a5451a520195201852017522175220c033186150c033
010b00200c03324510245102451024512245122751127510186151841516215184150c0031841516215134150c033114151321516415182151b4151d215224151861524415222151e4151d2151c4151b21518415
0112000003744030250a7040a005137441302508744080251b7110a704037440302524615080240a7440a02508744087250a7040c0241674416025167251652527515140240c7440c025220152e015220150a525
011200000c033247151f5152271524615227151b5051b5151f5201f5201f5221f510225212252022522225150c0331b7151b5151b715246151b5151b5051b515275202752027522275151f5211f5201f5221f515
011200000c0330802508744080250872508044187151b7151b7000f0251174411025246150f0240c7440c0250c0330802508744080250872508044247152b715275020f0251174411025246150f0240c7440c025
011200002452024520245122451524615187151b7151f71527520275202751227515246151f7151b7151f715295202b5212b5122b5152461524715277152e715275002e715275022e715246152b7152771524715
011200002352023520235122351524615177151b7151f715275202752027512275152461523715277152e7152b5202c5212c5202c5202c5202c5222c5222c5222b5202b5202b5222b515225151f5151b51516515
011200000c0330802508744080250872508044177151b7151b7000f0251174411025246150f0240b7440b0250c0330802508744080250872524715277152e715080242e715080242e715246150f0240c7440c025
__music__
01 01434144
00 02434144
00 01031244
02 02031244
01 13144344
00 15164344
00 13174344
02 15174344
00 18424344
00 18424344
00 18194344
00 18194344
01 18194344
00 18194344
00 1a1b4344
02 1c1d4344
01 13144344
00 15164344
00 13174344
02 15174344
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144

