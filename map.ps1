Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

[xml]$xaml = 
@"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="Window"
        Width="800"
        Height="600"
 
        ShowInTaskbar="True">
    <Grid Margin="20" ClipToBounds="True">
    <Canvas Name="canvas"/>
    </Grid>
</Window>
"@
 
$xaml_reader = New-Object System.Xml.XmlNodeReader $xaml
[System.Windows.Window]$window = [Windows.Markup.XamlReader]::Load($xaml_reader)




[System.Windows.Controls.Canvas]$canvas = $window.FindName("canvas")

$canvas.Background = [System.Windows.Media.Brushes]::Blue
$x = 0
$y = 0
$isDown = 0
$zoom = 2
$tileCount = [Math]::Pow(2,$zoom)
   function Fill
    {
        $XX = 0    
        for($x=0;  $x -lt $canvas.ActualWidth; $x += 256)
        {
            $YY=0
            for($y=0; $y -lt $canvas.ActualHeight; $y += 256)
            {
            
                addTile @{Z=$zoom;X=$XX;Y=$YY} "https://tile.openstreetmap.org/$zoom/$XX/$YY.png" $x $y
                $YY++
                $YY %= $tileCount

            }
         $XX++
         $XX %= $tileCount
         }
    }

    function Update
    {

        $toRemove = @()  
        $rightEdge = [double]::NegativeInfinity
        $rightX = 0
        $leftEdge = [double]::PositiveInfinity
        $leftX = 0
        $topEdge = [double]::PositiveInfinity
        $topY = 0
        $bottomEdge = [double]::NegativeInfinity
        $bottomY = 0
        foreach($child in $canvas.Children)
        {
            $prevX = [System.Windows.Controls.Canvas]::GetLeft($child)
            $prevY = [System.Windows.Controls.Canvas]::GetTop($child)

            [System.Windows.Controls.Canvas]::SetLeft($child, $prevX+$dx)
            [System.Windows.Controls.Canvas]::SetTop($child, $prevY+$dy)

            $childLeft = [System.Windows.Controls.Canvas]::GetLeft($child)
            $childTop = [System.Windows.Controls.Canvas]::GetTop($child)
        
            if(
                $childLeft -gt $canvas.ActualWidth -or
                $childTop -gt $canvas.ActualHeight -or
                $childLeft -lt  -$child.ActualWidth -or
                $childTop -lt -$child.ActualHeight) {$toRemove += $child}

        
            $childRight = $childLeft + $child.ActualWidth
            $childBottom = $childTop + $child.ActualHeight
            if($childRight -gt $rightEdge) {$rightEdge = $childRight; $rightX = $child.Tag.X}
            if($childLeft -lt $leftEdge) {$leftEdge = $childLeft; $leftX = $child.Tag.X}
            if($childTop -lt $topEdge) {$topEdge = $childTop; $topY = $child.Tag.Y}
            if($childBottom -gt $bottomEdge) {$bottomEdge = $childBottom; $bottomY = $child.Tag.Y}  
        }
    
        if($rightEdge -lt $canvas.ActualWidth)
        {
            $x = $rightEdge
            $y = $topEdge

            $XX = $rightX + 1
            $XX = $XX % $tileCount
            $YY = $topY

            while($y -lt $bottomEdge)
            {
                addTile @{Z=1;X=$XX;Y=$YY} "https://tile.openstreetmap.org/$zoom/$XX/$YY.png" $x $y
                $y += 256
                $YY += 1
                $YY = $YY % $tileCount
            }
        }

        if($leftEdge -gt 0)
        {
            $x = $leftEdge - 256
            $y = $topEdge

            $XX = ($rightX - 1 + $tileCount) % $tileCount  # wrap backward
            $YY = $topY

            while ($y -lt $bottomEdge) 
            {
                addTile @{Z=1;X=$XX;Y=$YY} "https://tile.openstreetmap.org/$zoom/$XX/$YY.png" $x $y
                $y += 256
                $YY = ($YY + 1) % $tileCount
            }
        }

        if($topEdge -gt 0)
        {
            $x = $leftEdge
            $y = $topEdge - 256

            $XX = $leftX
            $YY = ($topY - 1 + $tileCount) % $tileCount

            while ($x -lt $rightEdge) 
            {
                addTile @{Z=1;X=$XX;Y=$YY} "https://tile.openstreetmap.org/$zoom/$XX/$YY.png" $x $y
                $x += 256
                $XX = ($XX + 1) % $tileCount
            }
        }

        if($bottomEdge -lt $canvas.ActualHeight)
        {
                $x = $leftEdge
            $y = $bottomEdge

            $XX = $leftX
            $YY = ($topY + ($bottomEdge - $topEdge) / 256) % $tileCount

            while ($x -lt $rightEdge) 
            {
                addTile @{Z=1;X=$XX;Y=$YY} "https://tile.openstreetmap.org/$zoom/$XX/$YY.png" $x $y
                $x += 256
                $XX = ($XX + 1) % $tileCount
            }
        }



        foreach($child in $toRemove)
        {
            $canvas.Children.Remove($child)
        }

    }


$canvas.Add_MouseDown({
    param($sender, $e)
    $pos = $e.GetPosition($canvas)
    $global:x = $pos.X
    $global:y = $pos.Y
    $global:isDown = 1
})

$window.Add_MouseUp({
    param($sender, $e)
    $global:x = 0
    $global:y = 0
    $global:isDown = 0
})

$window.Add_MouseMove({
    param($sender, $e)
    if($isDown -eq 0) {return}
    $currentPos = $e.GetPosition($canvas)
    $dx = $currentPos.X - $x
    $dy = $currentPos.Y - $y
    $global:x = $currentPos.X
    $global:y = $currentPos.Y

    Update
    
})

$window.Add_SizeChanged({
    Update
})



function addTile
{
    param (
        $tag = @{},
        [string]$url,
        [double]$x=0,
        [double]$y=0,
        [double]$width=256,
        [double]$height=256
    )

    [System.Windows.Controls.Image] $image = New-Object System.Windows.Controls.Image
    $image.Source = New-Object System.Windows.Media.Imaging.BitmapImage(New-Object System.Uri($url))
    $image.Width = $width
    $image.Height = $height
    $image.Tag = $tag
    
    [System.Windows.Controls.Canvas]::SetLeft($image,$x)
    [System.Windows.Controls.Canvas]::SetTop($image,$y)

    $canvas.AddChild($image)
}

$window.Add_Loaded({
   Fill
   
})

$window.Add_StateChanged({
     $canvas.Children.Clear()
     Fill
 })



$result = $window.ShowDialog()



